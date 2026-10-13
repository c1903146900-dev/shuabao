extends RefCounted
## Original vector artwork, one distinct silhouette per catalog item.
static var cache:Dictionary={}
const ART:Dictionary={
	"iron_blade":["c6d3db", "c49b62", "<path d=\"M17 37L34 8L41 7L40 15L23 40Z\" fill=\"#a\"/><path d=\"M12 30L29 40M15 40L11 46\" stroke=\"#b\" stroke-width=\"4\"/>"],
	"secret_tome":["aa84d0", "edd2a3", "<path d=\"M11 11Q21 7 26 13Q35 8 43 12V41Q34 37 26 42Q18 37 11 41Z\" fill=\"#a\" stroke=\"#b\" stroke-width=\"2\"/><path d=\"M26 14V40M16 18L22 19M31 18L38 16M15 24L22 25M31 24L38 22\" stroke=\"#e9dbed\" stroke-width=\"1.5\"/>"],
	"mainspring":["c99f5d", "f0dcb4", "<g stroke=\"#a\" stroke-width=\"5\"><path d=\"M26 6V14M26 38V46M6 26H14M38 26H46M11 11L17 17M35 35L41 41M11 41L17 35M35 17L41 11\"/></g><circle cx=\"26\" cy=\"26\" r=\"14\" fill=\"#34434a\" stroke=\"#a\" stroke-width=\"5\"/><path d=\"M22 20Q35 14 35 27Q32 38 21 32Q15 28 22 23Q28 21 28 27\" fill=\"none\" stroke=\"#b\" stroke-width=\"2\"/>"],
	"sharp_lens":["9fc6d7", "e7d09c", "<circle cx=\"28\" cy=\"22\" r=\"14\" fill=\"#487b95\" stroke=\"#b\" stroke-width=\"4\"/><path d=\"M17 33L8 44\" stroke=\"#a\" stroke-width=\"6\"/><path d=\"M28 10L31 20L40 22L31 25L28 35L25 25L17 22L25 20Z\" fill=\"#a\"/>"],
	"cooling_core":["7fdaf0", "c4edfa", "<path d=\"M26 6L40 16V36L26 46L12 36V16Z\" fill=\"#255d81\" stroke=\"#a\" stroke-width=\"2\"/><path d=\"M26 10V42M15 18L37 34M15 34L37 18M20 13L26 18L32 13M20 39L26 34L32 39\" stroke=\"#b\" stroke-width=\"2\"/>"],
	"blood_crystal":["d95467", "f5b5a1", "<path d=\"M26 5L40 16L36 37L26 47L14 36L11 16Z\" fill=\"#a\" stroke=\"#b\" stroke-width=\"1.5\"/><path d=\"M26 5L21 22L26 47L31 22ZM11 16L21 22H31L40 16\" fill=\"none\" stroke=\"#b\" stroke-width=\"1.4\"/>"],
	"alloy_plate":["a4b8c6", "e2d8ae", "<path d=\"M15 7L38 11L44 37L25 46L8 30Z\" fill=\"#647d90\" stroke=\"#a\" stroke-width=\"3\"/><path d=\"M16 14L34 17L37 31L25 37L16 28Z\" fill=\"#a\"/><circle cx=\"15\" cy=\"10\" r=\"2\" fill=\"#b\"/><circle cx=\"40\" cy=\"36\" r=\"2\" fill=\"#b\"/><circle cx=\"24\" cy=\"42\" r=\"2\" fill=\"#b\"/>"],
	"wind_boots":["8ed9cd", "e1ead2", "<path d=\"M21 9H32L31 27L42 34L38 42H16L12 34L23 25Z\" fill=\"#a\" stroke=\"#b\" stroke-width=\"2\"/><path d=\"M19 19L5 13L13 27L5 24L15 35M17 38H40\" fill=\"none\" stroke=\"#b\" stroke-width=\"2\"/>"],
	"blood_pouch":["b64c64", "e2bd7e", "<path d=\"M20 9H32L34 18Q47 33 34 43Q22 49 14 38Q7 29 20 18Z\" fill=\"#a\" stroke=\"#b\" stroke-width=\"2\"/><path d=\"M19 13H34M26 22Q16 34 26 39Q36 34 26 22\" fill=\"#ef9689\" stroke=\"#b\" stroke-width=\"2\"/>"],
	"steady_ring":["d7bd78", "a1e0dd", "<ellipse cx=\"26\" cy=\"30\" rx=\"16\" ry=\"14\" fill=\"none\" stroke=\"#a\" stroke-width=\"6\"/><path d=\"M17 13L26 5L35 13L26 25Z\" fill=\"#b\" stroke=\"#a\" stroke-width=\"2\"/><path d=\"M17 30Q20 41 30 40\" fill=\"none\" stroke=\"#faedc5\" stroke-width=\"2\"/>"],
	"drill_core":["a8adb7", "d8a25c", "<path d=\"M27 5L39 28L30 38L16 30Z\" fill=\"#a\" stroke=\"#b\" stroke-width=\"2\"/><path d=\"M22 17L32 21M20 23L36 28M15 32L29 42M12 36L25 46\" stroke=\"#b\" stroke-width=\"4\"/>"],
	"living_tissue":["86c180", "d1ebb0", "<path d=\"M8 31Q10 14 25 8Q44 17 40 35Q23 48 8 31Z\" fill=\"#427857\" stroke=\"#a\" stroke-width=\"2\"/><path d=\"M13 32Q16 19 24 26Q33 33 35 17M14 36Q26 34 33 39\" fill=\"none\" stroke=\"#b\" stroke-width=\"3\"/><circle cx=\"18\" cy=\"19\" r=\"3\" fill=\"#a\"/><circle cx=\"28\" cy=\"15\" r=\"2\" fill=\"#a\"/>"],
	"piercing_core":["dbaa62", "eae5d0", "<path d=\"M31 4L42 19L22 37L15 29Z\" fill=\"#b\" stroke=\"#a\" stroke-width=\"2\"/><path d=\"M34 12L18 34M11 27L29 44M9 40L17 45\" stroke=\"#a\" stroke-width=\"3\"/><circle cx=\"18\" cy=\"35\" r=\"4\" fill=\"#af664c\"/>"],
	"quick_frame":["8cbbba", "e4ca8c", "<path d=\"M15 8L36 12L41 27L30 43L12 35L7 22Z\" fill=\"none\" stroke=\"#a\" stroke-width=\"5\"/><path d=\"M31 8L17 27H26L21 44L39 23H28Z\" fill=\"#b\"/>"],
	"guard_frame":["78aeb9", "dcd6a1", "<path d=\"M8 11L26 5L44 11L40 34L26 47L12 34Z\" fill=\"#294956\" stroke=\"#a\" stroke-width=\"3\"/><path d=\"M15 15L26 11L37 15L34 30L26 39L18 30Z\" fill=\"#a\"/><path d=\"M26 13V36M17 23H35\" stroke=\"#b\" stroke-width=\"3\"/>"],
	"duelist_edge":["e8ba67", "f7ecd1", "<path d=\"M9 42L34 5L34 26L20 38ZM42 44L24 17L24 35L33 41Z\" fill=\"#b\" stroke=\"#a\" stroke-width=\"1.5\"/><path d=\"M10 30L28 42M27 34L41 26\" stroke=\"#a\" stroke-width=\"4\"/>"],
	"thrust_spike":["edb361", "f9e6b4", "<path d=\"M27 3L33 24L30 33H24L21 24Z\" fill=\"#b\"/><path d=\"M26 28V48M11 29L26 36L41 29M12 21L26 30L40 21\" stroke=\"#a\" stroke-width=\"3\"/><path d=\"M9 15L13 9M39 8L43 15\" stroke=\"#f3d186\" stroke-width=\"2\"/>"],
	"rapid_blade":["83dfd2", "d7f6ed", "<path d=\"M14 38Q39 29 37 6L43 14Q46 32 19 43Z\" fill=\"#b\" stroke=\"#a\" stroke-width=\"1.5\"/><path d=\"M10 30L22 44M9 41L7 47M8 13H23M5 20H19M7 27H16\" stroke=\"#a\" stroke-width=\"3\"/>"],
	"bastion_shell":["a5b1cf", "e4c788", "<path d=\"M7 15L13 6L21 13L26 5L32 13L40 6L45 15L40 36L26 48L11 36Z\" fill=\"#596278\" stroke=\"#b\" stroke-width=\"2\"/><path d=\"M17 16H35V34L26 41L17 34Z\" fill=\"#a\"/><path d=\"M22 22H30V35H22Z\" fill=\"#354658\"/><path d=\"M8 22H17M35 22H44\" stroke=\"#b\" stroke-width=\"3\"/>"],
	"sanguine_edge":["d56c81", "efc19a", "<path d=\"M14 42L33 5Q43 23 24 38L19 46Z\" fill=\"#a\" stroke=\"#b\" stroke-width=\"1.5\"/><path d=\"M31 13L22 33M10 29L29 43\" stroke=\"#b\" stroke-width=\"3\"/><path d=\"M37 33Q29 44 38 47Q46 43 37 33\" fill=\"#a\"/>"],
	"living_shell":["8aca89", "d9eab1", "<path d=\"M10 14Q26 1 43 15L40 34L26 47L12 34Z\" fill=\"#416d54\" stroke=\"#a\" stroke-width=\"3\"/><path d=\"M26 39V14M26 23Q14 25 16 15Q26 14 26 23M26 31Q37 30 38 20Q27 21 26 31\" fill=\"#a\" stroke=\"#b\" stroke-width=\"1.5\"/>"],
	"focused_tome":["b68bdf", "eadab0", "<path d=\"M10 10L29 7L42 12V43L27 38L10 43Z\" fill=\"#584176\" stroke=\"#b\" stroke-width=\"2\"/><path d=\"M27 9V38M8 45L25 40L42 45\" stroke=\"#b\" stroke-width=\"2\"/><circle cx=\"26\" cy=\"24\" r=\"10\" fill=\"#a\"/><path d=\"M26 12L29 21L38 24L29 27L26 36L23 27L14 24L23 21Z\" fill=\"#f7e5c4\"/>"],
	"steady_stride":["8ac2d7", "dbc79a", "<path d=\"M13 7H27L25 27L35 36L30 44H8L6 34L16 26ZM30 12H40L39 30L47 38L43 45H34L38 36L31 28Z\" fill=\"#a\" stroke=\"#b\" stroke-width=\"2\"/><path d=\"M10 17H26M8 37H32M31 22H40\" stroke=\"#284b62\" stroke-width=\"3\"/>"],
	"normal_tonic":["da6466", "d9c895", "<path d=\"M20 8H32V18Q42 22 39 40Q26 48 13 40Q10 22 20 18Z\" fill=\"#a\" stroke=\"#b\" stroke-width=\"2\"/><path d=\"M19 8H33M15 29H37\" stroke=\"#b\" stroke-width=\"4\"/><path d=\"M26 23V38M20 31H32\" stroke=\"#ffe5ca\" stroke-width=\"2\"/>"],
	"special_tonic":["a886d5", "dceeb4", "<path d=\"M21 6H31V17L42 28L34 45H18L10 28L21 17Z\" fill=\"#a\" stroke=\"#b\" stroke-width=\"2\"/><path d=\"M20 7H32M26 19L30 28L37 30L30 33L26 41L22 33L15 30L22 28Z\" fill=\"#b\"/>"],
}
static func texture(id:String) -> Texture2D:
	if cache.has(id):return cache[id]
	var art:Array=ART.get(id,ART.iron_blade)
	var body:String=str(art[2]).replace('"#a"','"#'+str(art[0])+'"').replace('"#b"','"#'+str(art[1])+'"')
	var svg:String='<svg xmlns="http://www.w3.org/2000/svg" width="52" height="52" viewBox="0 0 52 52"><defs><radialGradient id="g"><stop stop-color="#'+art[0]+'" stop-opacity=".37"/><stop offset="1" stop-color="#0a1720"/></radialGradient></defs><rect width="52" height="52" fill="url(#g)"/><path d="M3 11V3H11M41 3H49V11M49 41V49H41M11 49H3V41" fill="none" stroke="#'+art[1]+'" stroke-opacity=".6"/>'+body+'</svg>'
	var image:=Image.new()
	image.load_svg_from_string(svg)
	var result:=ImageTexture.create_from_image(image)
	cache[id]=result
	return result
