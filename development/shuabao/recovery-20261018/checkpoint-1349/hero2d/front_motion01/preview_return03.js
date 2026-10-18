'use strict';
// Inspection renderer, not production reducer. Public phase/progress is already normalized.
const upper=new Image(), lower=new Image();
const returns=new Image();returns.src='upper_return_two_original.png';
upper.src='upper_q1_eight_original.png'; lower.src='lower_idle_walk_nine_original.png';
const canvas=document.getElementById('canvas'),ctx=canvas.getContext('2d');
const RELEASE_SPAN=.6000000238418579;
const anchors=[[210, 324], [177, 327], [183, 337], [198, 326], [243, 294], [234, 297], [182, 329], [188, 330]];
const upperScales=[1.0, 1.0, 0.926829268292683, 1.027027027027027, 1.0857142857142856, 0.9743589743589743, 1.027027027027027, 0.95];
const regions=[[11,29,359,510],[414,38,738,510],[789,54,1139,510],[1164,37,1528,507],[33,534,390,991],[422,539,774,992],[774,534,1138,996],[1157,522,1502,1004]];
let running=true,time=0,last=null,forced=-1;
document.getElementById('play').onclick=()=>{running=!running;document.getElementById('play').textContent=running?'Pause':'Play';};
document.getElementById('step').onclick=()=>{running=false;forced=(forced+1)%10;document.getElementById('play').textContent='Play';};
document.getElementById('phase').onchange=()=>{forced=-1;};
const smooth=t=>{t=Math.max(0,Math.min(1,t));return t*t*(3-2*t);};
// Waist is fixed. Each whole shoe is translated, not stretched. A continuous
// material field bridges the crotch; no separate limb cylinders or raster cuts.
function legVertex(x,y,phase,moving){
 if(!moving)return [x,y];
 const blend=smooth((y-70)/170),side=smooth((x-330)/40);
 const a=Math.sin(phase),b=Math.sin(phase+Math.PI);
 const dyL=14*a-6*Math.max(0,Math.cos(phase));
 const dyR=14*b-6*Math.max(0,Math.cos(phase+Math.PI));
 return [x,y+blend*(dyL*(1-side)+dyR*side)];
}
function triangle(image,src,dst){
 const [a,b,c]=src,[p,q,r]=dst;
 const det=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);
 if(Math.abs(det)<1e-8)throw Error('degenerate UV');
 const u=[(c[1]-a[1])/det,-(b[1]-a[1])/det],v=[-(c[0]-a[0])/det,(b[0]-a[0])/det];
 const A=(q[0]-p[0])*u[0]+(r[0]-p[0])*u[1],C=(q[0]-p[0])*v[0]+(r[0]-p[0])*v[1];
 const B=(q[1]-p[1])*u[0]+(r[1]-p[1])*u[1],D=(q[1]-p[1])*v[0]+(r[1]-p[1])*v[1];
 ctx.save();ctx.beginPath();ctx.moveTo(...p);ctx.lineTo(...q);ctx.lineTo(...r);ctx.closePath();ctx.clip();ctx.transform(A,B,C,D,p[0]-A*a[0]-C*a[1],p[1]-B*a[0]-D*a[1]);ctx.drawImage(image,0,0);ctx.restore();
}
function drawLegs(x,y,s,phase,moving){
 // First source cell only; other eight are rejected as a walk sequence.
 const xs=[224,240,260,280,300,320,330,350,370,390,410,430,450,470,480];
 const ys=[0,20,45,70,100,130,160,190,220,240,260,280,300,320];
 const point=(p)=>{const d=legVertex(...p,phase,moving);return [x+(d[0]-350)*s,y+(d[1]-20)*s];};
 for(let j=0;j<ys.length-1;j++)for(let i=0;i<xs.length-1;i++){
 const a=[xs[i],ys[j]],b=[xs[i+1],ys[j]],c=[xs[i+1],ys[j+1]],d=[xs[i],ys[j+1]];
 for(const t of [[a,b,c],[a,c,d]])triangle(lower,t,t.map(point));
 }
}
function frameFor(phase,p){
 if(phase==='idle')return 0;
 if(phase==='draw')return p<.35?0:p<.8?1:2;
 if(phase==='hold')return 2;
 if(phase==='release')return [3,4,5,8,9,0][Math.min(5,Math.floor(p*6))];
 throw Error('unknown phase');
}
function replay(t){
 const c=t%3.8;
 if(c<.7)return ['idle',0];
 if(c<1.5)return ['draw',(c-.7)/.8]; // Demonstration input drag, not a skill duration.
 if(c<2.0)return ['hold',1]; // Demonstration player hold, not an automatic release.
 if(c<2+RELEASE_SPAN)return ['release',(c-2)/RELEASE_SPAN];
 return ['idle',0];
}
function character(x,y,size,frame,moving){
 const s=size/582; // neutral alpha>=128 head y30 to sole y308: (324-30)+(308-20)
 drawLegs(x,y,s,time*6,moving);
 if(frame>=8){
 const rr=frame===8?[188,16,848,853]:[985,17,1663,856];
 const waist=frame===8?[555,500]:[1330,545], us=s*(frame===8?38/85:38/79);
 ctx.drawImage(returns,rr[0],rr[1],rr[2]-rr[0],rr[3]-rr[1],x+(rr[0]-waist[0])*us,y+(rr[1]-waist[1])*us,(rr[2]-rr[0])*us,(rr[3]-rr[1])*us);
 return;
 }
 const a=anchors[frame],sx=(frame%4)*384,sy=Math.floor(frame/4)*512;
 const r=regions[frame],w=r[2]-r[0],h=r[3]-r[1],us=s*upperScales[frame];
 ctx.drawImage(upper,r[0],r[1],w,h,x+(r[0]-sx-a[0])*us,y+(r[1]-sy-a[1])*us,w*us,h*us);
 ctx.strokeStyle='#d89f50';ctx.beginPath();ctx.moveTo(x-20,y+290*s);ctx.lineTo(x+20,y+290*s);ctx.stroke();
}
function tick(stamp){
 if(last!==null&&running)time+=Math.min(.1,(stamp-last)/1000);last=stamp;
 ctx.fillStyle=document.getElementById('bg').value;ctx.fillRect(0,0,canvas.width,canvas.height);
 let [phase,p]=replay(time),selected=document.getElementById('phase').value;
 if(selected!=='auto'){phase=selected;p=Number(document.getElementById('progress').value);}
 const frame=forced>=0?forced:frameFor(phase,p);
 if(upper.complete&&upper.naturalWidth&&lower.complete&&lower.naturalWidth&&returns.complete&&returns.naturalWidth){
 character(230,300,240,frame,false);character(600,300,240,frame,true);character(900,350,60,frame,true);
 ctx.fillStyle='#cc9163';ctx.font='16px sans-serif';ctx.fillText('stationary / 240 px',130,540);ctx.fillText('moving lower / 240 px',490,540);ctx.fillText('60 px',870,540);
 document.getElementById('status').textContent=`${phase} ${p.toFixed(3)} | upper frame ${frame} | release clip span ${RELEASE_SPAN}s | known: upper frame switching/waist registration/return jump require visual iteration`;
 }
 requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
// Explicit test hook; no gameplay dispatch or synthetic accepted-release event.
window.hero2dInspection={legVertex,frameFor,releaseSpan:RELEASE_SPAN};
