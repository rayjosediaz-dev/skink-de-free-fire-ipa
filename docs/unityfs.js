// UnityFS v6-v8 inspector. Processes files locally; no network upload.
const MAX=128*1024*1024;
class Reader {
 constructor(bytes,pos=0){this.b=bytes;this.p=pos}
 need(n){if(n<0||this.p+n>this.b.length)throw Error('Datos incompletos en '+this.p)}
 num(n){this.need(n);let v=0;for(let i=0;i<n;i++)v=v*256+this.b[this.p++];if(!Number.isSafeInteger(v))throw Error('Número fuera de rango');return v}
 str(){let end=this.p;while(end<this.b.length&&end-this.p<1024&&this.b[end])end++;if(end>=this.b.length||end-this.p>=1024)throw Error('Cadena sin terminador');let s=new TextDecoder().decode(this.b.subarray(this.p,end));this.p=end+1;return s}
 align(){this.p=(this.p+15)&~15}
}
function lz4(src,size){
 if(size>MAX)throw Error('Bloque demasiado grande');
 const out=new Uint8Array(size);let i=0,j=0;
 while(i<src.length){
  const token=src[i++];let lit=token>>>4;
  if(lit===15){let n;do{if(i>=src.length)throw Error('LZ4 literal truncado');n=src[i++];lit+=n}while(n===255)}
  if(i+lit>src.length||j+lit>size)throw Error('LZ4 literal fuera de rango');
  out.set(src.subarray(i,i+lit),j);i+=lit;j+=lit;
  if(i===src.length)break;
  if(i+2>src.length)throw Error('LZ4 offset truncado');
  const off=src[i]|src[i+1]<<8;i+=2;if(!off||off>j)throw Error('LZ4 offset inválido');
  let len=(token&15)+4;
  if((token&15)===15){let n;do{if(i>=src.length)throw Error('LZ4 longitud truncada');n=src[i++];len+=n}while(n===255)}
  if(j+len>size)throw Error('LZ4 desbordamiento');
  for(let k=0;k<len;k++)out[j+k]=out[j+k-off];j+=len;
 }
 if(j!==size)throw Error('LZ4 tamaño inesperado '+j+'/'+size);
 return out;
}
function decode(src,size,method){
 if(size>MAX)throw Error('Se excedió el límite de 128 MB');
 if(method===0){if(src.length!==size)throw Error('Bloque sin comprimir con tamaño incorrecto');return src}
 if(method===2||method===3)return lz4(src,size);
 if(method===1)throw Error('LZMA no disponible en el navegador todavía');
 throw Error('Compresión no compatible: '+method);
}
function scan(bytes){
 // ASCII path references in decoded payloads, not proof of available meshes.
 const s=new TextDecoder('latin1').decode(bytes);
 return [...new Set((s.match(/assets\/[a-z0-9_./-]{1,480}\/wardrobe_(?:hair|faces|shirt|pants|shoes)\/[a-z0-9_./-]{1,350}\.asset/gi)||[]))].slice(0,3000);
}
export function inspectUnityFS(bytes){
 const r=new Reader(bytes);
 if(r.str()!=='UnityFS')throw Error('No es un archivo UnityFS');
 const revision=r.num(4);if(revision<6||revision>8)throw Error('Revisión UnityFS no soportada: '+revision);
 const player=r.str(),version=r.str(),length=r.num(8),packed=r.num(4),expanded=r.num(4),flags=r.num(4);
 if(revision>=7)r.align();
 if(length>bytes.length||packed>length)throw Error('Cabecera UnityFS incorrecta');
 const atEnd=!!(flags&0x80);
 const metaAt=atEnd?length-packed:r.p;
 if(metaAt<0||metaAt+packed>length)throw Error('Metadatos fuera del archivo');
 const metadata=decode(bytes.subarray(metaAt,metaAt+packed),expanded,flags&63);
 const t=new Reader(metadata,16);t.need(0);
 const blockCount=t.num(4);if(blockCount>50000)throw Error('Demasiados bloques');
 const blocks=[];for(let i=0;i<blockCount;i++)blocks.push({size:t.num(4),packed:t.num(4),method:t.num(2)&63});
 const entryCount=t.num(4);if(entryCount>50000)throw Error('Demasiadas entradas');
 const entries=[];
 for(let i=0;i<entryCount;i++)entries.push({offset:t.num(8),size:t.num(8),flags:t.num(4),name:t.str()});
 let off=atEnd?r.p:metaAt+packed;if(flags&0x200)off=(off+15)&~15;
 const end=atEnd?metaAt:length;
 let total=0;for(const b of blocks){total+=b.size;if(total>MAX)throw Error('El contenido expandido supera 128 MB')}
 const payload=new Uint8Array(total);let p=0;
 for(const b of blocks){if(off+b.packed>end)throw Error('Bloque fuera del archivo');payload.set(decode(bytes.subarray(off,off+b.packed),b.size,b.method),p);off+=b.packed;p+=b.size}
 const references=[];
 for(const e of entries){
  if(e.offset+e.size>payload.length)continue;
  if(e.name.startsWith('CAB-')||e.name.endsWith('.assets'))references.push(...scan(payload.subarray(e.offset,e.offset+e.size)));
 }
 const unique=[...new Set(references)];
 const wardrobe={};for(const [folder,label] of Object.entries({hair:'Cabello',faces:'Rostro',shirt:'Torso',pants:'Pantalón',shoes:'Zapatos'}))wardrobe[label]=unique.filter(x=>x.toLowerCase().includes('/wardrobe_'+folder+'/'));
 const characterText=entries.map(x=>x.name).concat(unique).join(' ').toLowerCase();
 return {revision,version,player,blocks:blockCount,entries:entries.map(x=>x.name),entryDetails:entries,characters:['Alok','Dimitri'].filter(n=>characterText.includes(n.toLowerCase())),wardrobe,references:unique,notice:'Índice y referencias decodificados. No se han reconstruido Mesh, Texture2D, materiales ni modelos completos.'};
}
