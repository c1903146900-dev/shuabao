'use strict';
const upper=new Image(),lower=new Image(),parts=new Image();
upper.src='upper_q1_eight_original.png';lower.src='lower_idle_walk_nine_original.png';parts.src='neutral_parts_original.png';
const canvas=document.getElementById('canvas'),ctx=canvas.getContext('2d');
const smooth=t=>{t=Math.max(0,Math.min(1,t));return t*t*(3-2*t);};
let running=true,time=0,last=null,rejected=0,minArea=Infinity;
document.getElementById('play').onclick=()=>{running=!running;document.getElementById('play').textContent=running?'Pause':'Play';};
const mix=(a,b,t)=>a.map((v,i)=>v+(b[i]-v)*t),rot=(p,a)=>[p[0]*Math.cos(a)-p[1]*Math.sin(a),p[0]*Math.sin(a)+p[1]*Math.cos(a)];
function pose(phase,p){
 const n={w:[92,310],angle:0,lean:0},d={w:[94,195],angle:-.18,lean:-.3},s={w:[115,325],angle:-.7,lean:.65},f={w:[222,330],angle:-1.05,lean:.4};
 function lerp(a,b,t){t=smooth(t);return {w:mix(a.w,b.w,t),angle:a.angle+(b.angle-a.angle)*t,lean:a.lean+(b.lean-a.lean)*t};}
 if(phase==='draw')return lerp(n,d,p);if(phase==='release'){if(p<.25)return lerp(d,s,p/.25);if(p<.5)return lerp(s,f,(p-.25)/.25);return lerp(f,n,(p-.5)/.5);}return n;
}
function replay(t){let c=t%3.8;if(c<.7)return ['idle',0];if(c<1.5)return ['draw',(c-.7)/.8];if(c<2)return ['draw',1];if(c<2.6000000238418579)return ['release',(c-2)/.6000000238418579];return ['idle',0];}
function bodyPoint(x,y,p){
 // Head/hair are one rigid transformed region; no stretching of face.
 const headAngle=p.lean*.065,headShift=[p.lean*20,p.lean*12];
 const h=rot([x-205,y-240],headAngle).map((v,i)=>v+[205,240][i]+headShift[i]);
 if(y<=240)return h;
 const w=1-smooth((y-240)/90),balance=smooth((x-230)/80)*smooth((y-225)/65)*(1-smooth((y-395)/60));
 return [x+(h[0]-x)*w-balance*p.lean*18,y+(h[1]-y)*w+balance*p.lean*10];
}
function sleevePoint(x,y,p){
 const srcS=[1435,150],srcW=[1000,510],v=[srcW[0]-srcS[0],srcW[1]-srcS[1]],len=Math.hypot(...v),u=v.map(z=>z/len),n=[-u[1],u[0]];
 const rel=[x-srcS[0],y-srcS[1]],t=(rel[0]*u[0]+rel[1]*u[1])/len,lateral=rel[0]*n[0]+rel[1]*n[1];
 const S=bodyPoint(145,245,p),W=p.w,D=[W[0]-S[0],W[1]-S[1]],L=Math.hypot(...D);if(L<10)throw Error('sleeve axis collapsed');
 const base=[S[0]+D[0]*t-D[1]/L*lateral*.18,S[1]+D[1]*t+D[0]/L*lateral*.18];
 const vW=[base[0]-W[0],base[1]-W[1]],radius=Math.hypot(...vW);
 const desired=Math.atan2(60,-110)+p.angle,actual=Math.atan2(D[1],D[0]);let delta=desired-actual;while(delta>Math.PI)delta-=Math.PI*2;while(delta< -Math.PI)delta+=Math.PI*2;
 // Radial twist of the full continuous sleeve; fixed shoulder and exact cuff center.
 const angle=delta*(1-smooth(radius/L));const q=rot(vW,angle);return [W[0]+q[0],W[1]+q[1]];
}

function mesh(image,rect,nx,ny,map){
 const vertices=[],uvs=[],tris=[];
 for(let j=0;j<=ny;j++)for(let i=0;i<=nx;i++){const uv=[rect[0]+(rect[2]-rect[0])*i/nx,rect[1]+(rect[3]-rect[1])*j/ny];uvs.push(uv);vertices.push(map(...uv));}
 for(let j=0;j<ny;j++)for(let i=0;i<nx;i++){const a=j*(nx+1)+i,b=a+1,d=a+nx+1,c=d+1;tris.push([a,b,c],[a,c,d]);}
 for(const t of tris){const [a,b,c]=t.map(i=>vertices[i]),area=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);minArea=Math.min(minArea,area);if(!(area>1e-6)){rejected++;return false;}}
 for(const t of tris)triangle(image,t.map(i=>uvs[i]),t.map(i=>vertices[i]));flushTriangles(image);return true;
}
// Shared-edge GPU rasterization avoids independent Canvas clip antialias cracks.
// One transparent offscreen layer per mesh, then the existing semantic Canvas clip applies.
const rasterCanvas=document.createElement('canvas');rasterCanvas.width=1100;rasterCanvas.height=600;
const gl=rasterCanvas.getContext('webgl',{alpha:true,premultipliedAlpha:true,antialias:false,preserveDrawingBuffer:true});
if(!gl)throw Error('WebGL mesh rasterizer unavailable');
function shader(type,code){const sh=gl.createShader(type);gl.shaderSource(sh,code);gl.compileShader(sh);if(!gl.getShaderParameter(sh,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(sh));return sh;}
const program=gl.createProgram();gl.attachShader(program,shader(gl.VERTEX_SHADER,'attribute vec2 pos; attribute vec2 uv; varying vec2 tex; void main(){gl_Position=vec4(pos.x/550.0-1.0,1.0-pos.y/300.0,0.,1.);tex=uv;}'));gl.attachShader(program,shader(gl.FRAGMENT_SHADER,'precision mediump float; uniform sampler2D atlas; varying vec2 tex; void main(){gl_FragColor=texture2D(atlas,tex);}'));gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(program));gl.useProgram(program);
const vertexBuffer=gl.createBuffer(),positionLocation=gl.getAttribLocation(program,'pos'),uvLocation=gl.getAttribLocation(program,'uv'),textureCache=new Map();let rasterVertices=[];
gl.bindBuffer(gl.ARRAY_BUFFER,vertexBuffer);gl.enableVertexAttribArray(positionLocation);gl.enableVertexAttribArray(uvLocation);gl.vertexAttribPointer(positionLocation,2,gl.FLOAT,false,16,0);gl.vertexAttribPointer(uvLocation,2,gl.FLOAT,false,16,8);gl.uniform1i(gl.getUniformLocation(program,'atlas'),0);gl.disable(gl.DEPTH_TEST);gl.disable(gl.CULL_FACE);gl.enable(gl.BLEND);gl.blendFunc(gl.ONE,gl.ONE_MINUS_SRC_ALPHA);gl.viewport(0,0,1100,600);
function triangle(image,src,dst){
 const t=ctx.getTransform();for(let i=0;i<3;i++){const [x,y]=dst[i];rasterVertices.push(t.a*x+t.c*y+t.e,t.b*x+t.d*y+t.f,src[i][0]/image.naturalWidth,src[i][1]/image.naturalHeight);}
}
function flushTriangles(image){
 if(!rasterVertices.length)return;let texture=textureCache.get(image);if(!texture){texture=gl.createTexture();textureCache.set(image,texture);gl.bindTexture(gl.TEXTURE_2D,texture);gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL,true);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,image);}else gl.bindTexture(gl.TEXTURE_2D,texture);
 gl.clearColor(0,0,0,0);gl.clear(gl.COLOR_BUFFER_BIT);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(rasterVertices),gl.STREAM_DRAW);gl.drawArrays(gl.TRIANGLES,0,rasterVertices.length/4);rasterVertices=[];
 ctx.save();ctx.setTransform(1,0,0,1,0,0);ctx.drawImage(rasterCanvas,0,0);ctx.restore();
}
function legVertex(x,y,phase,moving){
 if(!moving)return [x,y];
 const blend=smooth((y-70)/170),side=smooth((x-330)/40);
 const a=Math.sin(phase),b=Math.sin(phase+Math.PI);
 const dyL=14*a-6*Math.max(0,Math.cos(phase));
 const dyR=14*b-6*Math.max(0,Math.cos(phase+Math.PI));
 return [x,y+blend*(dyL*(1-side)+dyR*side)];
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
 flushTriangles(lower);
}

const oldArm=[[0,225],[95,225],[119,248],[140,280],[142,310],[120,350],[98,400],[86,485],[0,485]];
function pathBody(poly,p){ctx.beginPath();poly.forEach((v,i)=>{const q=bodyPoint(...v,p);i?ctx.lineTo(...q):ctx.moveTo(...q);});ctx.closePath();}
function sleeveDistalClip(p){
 // Same continuous sleeve, split only for chest occlusion. No independent joint rotations.
 const S=[1435,150],W=[1000,510],D=[W[0]-S[0],W[1]-S[1]],L=Math.hypot(...D),N=[-D[1]/L,D[0]/L],poly=[];
 for(const [t,l] of [[.30,-500],[1.8,-500],[1.8,500],[.30,500]])poly.push([S[0]+D[0]*t+N[0]*l,S[1]+D[1]*t+N[1]*l]);
 ctx.beginPath();for(let e=0;e<4;e++)for(let j=0;j<24;j++){const uv=mix(poly[e],poly[(e+1)%4],j/24),q=sleevePoint(...uv,p);e||j?ctx.lineTo(...q):ctx.moveTo(...q);}ctx.closePath();ctx.clip();
}
function hero(x,y,size,p,moving){
 const scale=size/582;drawLegs(x,y,scale,time*6,moving);
 ctx.save();ctx.translate(x-210*scale,y-324*scale);ctx.scale(scale,scale);
 // Shoulder root is behind the original shoulder cap. The distal sleeve may cross the chest.
 const okSleeve=mesh(parts,[868,29,1513,697],32,32,(a,b)=>sleevePoint(a,b,p));
 // The replacement cloth is bounded by the torso contour, never a rectangular external silhouette.
 ctx.save();pathBody([[130,275],[150,280],[152,326],[121,350],[127,313]],p);ctx.clip();
 mesh(parts,[390,225,520,455],6,10,(a,b)=>bodyPoint(120+(a-390)*35/130,270+(b-225)*85/230,p));ctx.restore();
 ctx.save();ctx.beginPath();ctx.rect(-200,-200,1000,1000);for(let i=0;i<oldArm.length;i++){const q=bodyPoint(...oldArm[i],p);i?ctx.lineTo(...q):ctx.moveTo(...q);}ctx.closePath();ctx.clip('evenodd');
 ctx.save();ctx.translate(205+p.lean*20,240+p.lean*12);ctx.rotate(p.lean*.065);ctx.translate(-205,-240);ctx.drawImage(upper,11,29,348,211,11,29,348,211);ctx.restore();
 const okBody=mesh(upper,[11,240,359,510],20,20,(a,b)=>bodyPoint(a,b,p));ctx.restore();
 ctx.save();sleeveDistalClip(p);mesh(parts,[868,29,1513,697],32,32,(a,b)=>sleevePoint(a,b,p));ctx.restore();
 // A single rigid hand+brush; clip away the generated extra cuff, not its skin wrist.
 ctx.save();ctx.translate(...p.w);ctx.rotate(p.angle);ctx.scale(.31,.31);ctx.translate(-1890,-263);
 ctx.beginPath();[[1612,0],[1860,0],[1860,210],[1910,250],[1885,300],[1850,350],[1870,724],[1612,724]].forEach((v,i)=>i?ctx.lineTo(...v):ctx.moveTo(...v));ctx.closePath();ctx.clip();ctx.drawImage(parts,0,0);ctx.restore();ctx.restore();return okBody&&okSleeve;
}
function tick(stamp){if(last!==null&&running)time+=Math.min(.1,(stamp-last)/1000);last=stamp;
 ctx.fillStyle=document.getElementById('bg').value;ctx.fillRect(0,0,1100,600);let [phase,p]=replay(time);const chosen=document.getElementById('phase').value;if(chosen!=='auto'){phase=chosen;p=+document.getElementById('progress').value;}
 rejected=0;minArea=Infinity;
 if(upper.naturalWidth&&lower.naturalWidth&&parts.naturalWidth){try{const a=pose(phase,p);hero(230,300,240,a,false);hero(600,300,240,a,true);hero(900,350,60,a,true);document.getElementById('status').textContent=phase+' '+p.toFixed(3)+' | rejected meshes '+rejected+' | minimum triangle area '+minArea.toFixed(4)+' | assembly and animation unaccepted';}catch(e){document.getElementById('status').textContent='REJECT '+e.message;}}
 requestAnimationFrame(tick);
}
window.frontRigInspection={pose,bodyPoint,sleevePoint};requestAnimationFrame(tick);
