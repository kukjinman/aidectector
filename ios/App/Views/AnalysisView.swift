import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import ImageIO

struct AnalysisView: View {
    enum Mode: String { case text = "텍스트 분석", media = "미디어 분석", url = "URL 분석" }
    let mode: Mode
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: CreditStore
    @State private var input = ""
    @AppStorage("analysisConsentSignature") private var consentSignature = ""
    @State private var showingConsent = false
    @State private var pendingConsentSignature = ""
    private var currentConsentSignature: String {
        let base = AnalysisConsent.signature(store.configuration)
        guard !base.isEmpty else { return "" }
        return base + "|brief-v1|" + mode.rawValue
    }
    private var accepted: Bool {
        !currentConsentSignature.isEmpty && consentSignature.components(separatedBy: "\n").contains(currentConsentSignature)
    }
    private var transferNotice: String {
        if store.configuration?.demo == true { return "선택한 자료로 데모 분석을 실행합니다. 외부 AI 업체에는 전송하지 않습니다." }
        let provider = store.configuration?.mediaProviderName ?? "외부 분석 업체"
        switch mode {
        case .text: return "입력한 텍스트를 GPTZero에 전송해 AI 생성 가능성을 분석합니다."
        case .url: return "입력한 링크에서 Instagram 공개 미리보기 이미지를 가져와 \(provider)에 전송해 분석합니다."
        case .media: return "선택한 사진 또는 지원 영상을 \(provider)에 전송해 AI 생성 가능성을 분석합니다."
        }
    }
    @State private var busy = false
    @State private var error: String?
    @State private var result: AnalyzeSuccessResponse?
    @State private var photo: PhotosPickerItem?
    @State private var data: Data?
    @State private var contentType = "image/jpeg"
    @State private var filename = ""
    @State private var importing = false
    @State private var loadingMedia = false
    // Retained for an uncertain network outcome. An explicit new analysis resets it.
    @State private var requestID = UUID().uuidString
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                Text(mode.rawValue).font(.largeTitle.bold())
                if mode == .text {
                    if store.configuration?.textAvailable == false { Text("텍스트 분석은 GPTZero API 설정 후 이용할 수 있습니다.").font(.footnote).foregroundStyle(.orange) }
                    Text("250~10,000자 · 긴 영문 글에 가장 적합합니다. 언어에 따라 정확도가 달라집니다.").font(.footnote).foregroundStyle(.secondary)
                    TextEditor(text:$input).frame(minHeight:220).padding(10).background(.background,in:RoundedRectangle(cornerRadius:18))
                    Text("\(input.count) / 10,000자").font(.caption).foregroundStyle(.secondary)
                } else if mode == .url {
                    Text("Instagram 공개 게시물·릴스의 미리보기 이미지를 분석합니다. 영상 전체 분석은 파일을 선택해 주세요.").font(.subheadline).foregroundStyle(.secondary)
                    TextField("https://www.instagram.com/p/…",text:$input).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).textFieldStyle(.roundedBorder)
                    PasteButton(payloadType: String.self) { values in input = values.first ?? "" }
                } else {
                    if store.configuration?.videoAvailable == false { Text("현재 제공업체는 이미지만 지원합니다.").font(.footnote).foregroundStyle(.orange) }
                    Text("큰 사진도 선택할 수 있습니다. 전송용 사진은 자동으로 축소·압축됩니다. 원본은 변경되지 않으며, 압축은 분석 결과에 영향을 줄 수 있습니다.\n지원 영상은 10초·10MB 이하입니다.").font(.subheadline).foregroundStyle(.secondary)
                    PhotosPicker(selection:$photo,matching:.images) { Label("사진 보관함",systemImage:"photo") }.buttonStyle(.borderedProminent)
                    Button { importing = true } label: { Label("파일에서 이미지·영상 선택",systemImage:"folder") }.buttonStyle(.bordered)
                    if loadingMedia { ProgressView("파일 준비 중…") }
                    if !filename.isEmpty { Label(filename,systemImage:"checkmark.circle").font(.subheadline) }
                    if let data, let image = UIImage(data:data) { Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:230).clipShape(RoundedRectangle(cornerRadius:18)) }
                }
                if store.configuration?.demo == true { Text("데모 결과는 실제 판별이 아니며 횟수가 차감되지 않습니다.").font(.footnote).foregroundStyle(.orange) }
                Button {
                    if accepted { Task { await analyze() } }
                    else { pendingConsentSignature = currentConsentSignature; showingConsent = true }
                } label: {
                    HStack { if busy { ProgressView().tint(.white) }; Text(busy ? "분석 중…" : (store.configuration?.billingEnabled == false ? "분석하기 · 개발 모드" : "분석하기 · 1회 사용")).font(.headline) }.frame(maxWidth:.infinity).padding(8)
                }.buttonStyle(.borderedProminent).disabled(store.configuration == nil || busy || loadingMedia || (mode == .text && store.configuration?.textAvailable == false) || (mode == .media ? data == nil : input.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty))
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                if let result {
                    ResultCard(result:result)
                    Text("분석 API: \(result.provider)").font(.caption).foregroundStyle(.secondary)
                    Button("새 분석 시작") { self.result = nil; requestID = UUID().uuidString }
                }
                NavigationLink("횟수권 충전") { CreditShopView() }
            }.padding(22).disabled(busy)
        }.background(AppBackground()).navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .sheet(isPresented:$showingConsent) {
                VStack(alignment:.leading,spacing:20) {
                    Label("분석 전 확인",systemImage:"hand.raised.fill").font(.title2.bold())
                    Text(transferNotice).font(.body)
                    Text("만 14세 이상이며 이용약관과 위 전송에 동의합니다. 동의는 이 기기에 저장되며 설정에서 철회할 수 있습니다.").font(.footnote).foregroundStyle(.secondary)
                    HStack {
                        Link("개인정보처리방침",destination:AppConfig.legalURL("privacy"))
                        Link("이용약관",destination:AppConfig.legalURL("terms"))
                    }.font(.footnote)
                    Button {
                        guard !pendingConsentSignature.isEmpty, pendingConsentSignature == currentConsentSignature else { showingConsent = false; return }
                        consentSignature = (consentSignature.isEmpty ? "" : consentSignature + "\n") + pendingConsentSignature
                        showingConsent = false
                        Task { await analyze() }
                    } label: { Text("동의하고 분석").font(.headline).frame(maxWidth:.infinity).padding(8) }
                    .buttonStyle(.borderedProminent)
                    Button("취소",role:.cancel) { showingConsent = false }.frame(maxWidth:.infinity)
                }.padding(24).presentationDetents([.medium,.large]).presentationDragIndicator(.visible)
            }
            .onChange(of: input) { _,_ in requestID = UUID().uuidString; result = nil }
            .onChange(of: photo) { _,item in
                guard let item else { return }
                loadingMedia = true
                Task { @MainActor in
                    defer { loadingMedia = false }
                    do {
                        guard let original = try await item.loadTransferable(type:Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                        try setMedia(original,type:"image/jpeg",name:"선택한 사진")
                    } catch { self.error = "사진을 준비하지 못했습니다. 다른 사진을 선택해 주세요."; data = nil }
                }
            }
            .fileImporter(isPresented:$importing,allowedContentTypes:store.configuration?.videoAvailable == false ? [.jpeg,.png,.webP,.heic] : [.jpeg,.png,.webP,.heic,.mpeg4Movie,.quickTimeMovie]) { selection in
                do {
                    let url = try selection.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let info = try url.resourceValues(forKeys:[.fileSizeKey,.contentTypeKey])
                    if info.contentType?.conforms(to: .movie) == true, (info.fileSize ?? Int.max) > 10*1024*1024 { throw CocoaError(.fileReadTooLarge) }
                    try setMedia(Data(contentsOf:url,options:.mappedIfSafe),type:info.contentType?.preferredMIMEType ?? "application/octet-stream",name:url.lastPathComponent)
                } catch { self.error = "파일을 준비하지 못했습니다. 지원 사진 또는 10MB 이하 영상을 선택해 주세요."; data = nil }
            }
    }
    private func setMedia(_ newData: Data,type:String,name:String) throws {
        let prepared: Data
        if type.hasPrefix("image/") {
            prepared = try prepareImage(newData)
        } else {
            guard newData.count <= 10*1024*1024 else { throw CocoaError(.fileReadTooLarge) }
            prepared = newData
        }
        data = prepared; contentType = type.hasPrefix("image/") ? "image/jpeg" : type; filename = name; error = nil; result = nil; requestID = UUID().uuidString
    }
    // Downsample while decoding to avoid allocating the full-resolution bitmap.
    // 900 KB is our conservative transfer budget, not a documented provider limit.
    private func prepareImage(_ original: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(original as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        for edge in [2048, 1600, 1200, 800, 512] {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: edge,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let image = UIImage(cgImage: thumbnail)
            for quality in [0.9, 0.8, 0.65] {
                if let jpeg = image.jpegData(compressionQuality: quality), jpeg.count <= 900_000 { return jpeg }
            }
        }
        throw CocoaError(.fileReadTooLarge)
    }
    @MainActor private func analyze() async {
        guard accepted else { error = "외부 AI 전송 안내에 동의해 주세요."; return }
        busy = true; error = nil
        defer { busy = false }
        var body: [String:Any] = [:]
        switch mode {
        case .text: body["text"] = input.trimmingCharacters(in:.whitespacesAndNewlines)
        case .url: body["url"] = input.trimmingCharacters(in:.whitespacesAndNewlines)
        case .media: body = ["media":data!.base64EncodedString(),"contentType":contentType]
        }
        do {
            let response = try await AIDetectorAPI.analyze(body:body,requestID:requestID)
            let saveHistory = result == nil
            result = response
            if saveHistory {
                context.insert(HistoryRecord(sourceURL:mode == .url ? input : "",thumbnailURL:response.thumbnailUrl,aiProbability:response.aiProbability,label:response.label,mediaType:response.mediaType,provider:response.provider,analyzedAt:ISO8601DateFormatter().date(from:response.analyzedAt) ?? Date()))
                do { try context.save() } catch { self.error = "분석은 완료됐지만 기기에 기록을 저장하지 못했습니다." }
            }
            result = response
            await store.refresh()
        } catch {
            self.error = error.localizedDescription
            if case AIDetectorAPIError.server(let code,_) = error, code != "REQUEST_PENDING" { requestID = UUID().uuidString }
            await store.refresh()
        }
    }
}
