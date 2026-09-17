import { test } from 'node:test';
import assert from 'node:assert/strict';
import Fastify from 'fastify';
import { engineeringKey, protectEngineering, seedEngineering } from '../src/engineering.js';
import { Ledger } from '../src/billing/ledger.js';
test('engineering refuses production and weak keys',()=>{
 assert.throws(()=>engineeringKey({ENGINEERING_MODE:'true',NODE_ENV:'production'}));
 assert.throws(()=>engineeringKey({ENGINEERING_MODE:'true',NODE_ENV:'development',ENGINEERING_KEY:'short'}));
 assert.equal(engineeringKey({NODE_ENV:'production'}),undefined);
});
test('private engineering API authenticates and seed never refills spent credits',async()=>{
 const key='a'.repeat(64);const ledger=new Ledger(':memory:');const app=Fastify();
 protectEngineering(app,key);app.get('/check',async()=>({ok:true}));
 try {
 assert.equal((await app.inject('/check')).statusCode,401);
 assert.equal((await app.inject({url:'/check',headers:{authorization:'Bearer '+'b'.repeat(64)}})).statusCode,401);
 assert.equal((await app.inject({url:'/check',headers:{authorization:'Bearer '+key}})).statusCode,200);
 seedEngineering(ledger,key);const wallet=ledger.wallet(key);assert.equal(wallet.balance,20);
 ledger.reserve(wallet.id,'job','hash');ledger.finish(wallet.id,'job',{ok:true});
 seedEngineering(ledger,key);assert.equal(ledger.balance(wallet.id),19);
 }finally{await app.close();ledger.close();}
});
