const fs=require('fs'),vm=require('vm');
const context={Image:class{},document:{getElementById:()=>({getContext:()=>({})})},window:{},requestAnimationFrame:()=>{}};
vm.createContext(context);vm.runInContext(fs.readFileSync(__dirname+'/preview.js','utf8'),context);
const f=context.window.hero2dInspection.legVertex;
let min=Infinity,count=0,maxShoeResidual=0;
const xs=[224,240,260,280,300,320,330,350,370,390,410,430,450,470,480],ys=[0,20,45,70,100,130,160,190,220,240,260,280,300,320];
for(let k=0;k<=360;k++){const ph=k*Math.PI/180;
 for(let j=0;j<ys.length-1;j++)for(let i=0;i<xs.length-1;i++){
 const a=[xs[i],ys[j]],b=[xs[i+1],ys[j]],c=[xs[i+1],ys[j+1]],d=[xs[i],ys[j+1]];
 for(const tri of [[a,b,c],[a,c,d]]){const [p,q,r]=tri.map(v=>f(...v,ph,true));const area=(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0]);min=Math.min(min,area);count++;}}
 for(const side of [[240,270,300],[400,430,460]]){const base=f(side[0],260,ph,true)[1]-260;for(const x of side)for(const y of [260,280,300])maxShoeResidual=Math.max(maxShoeResidual,Math.abs(f(x,y,ph,true)[1]-y-base));}
}
const result={accepted:min>0&&maxShoeResidual<1e-10,sampled_triangle_count:count,min_signed_double_area:min,shoe_translation_residual:maxShoeResidual,scope:'Numerical sampled lower mesh only; browser playback and visible seams unverified'};
fs.writeFileSync(__dirname+'/MESH_CHECK.json',JSON.stringify(result,null,2));console.log(result);if(!result.accepted)process.exit(1);
