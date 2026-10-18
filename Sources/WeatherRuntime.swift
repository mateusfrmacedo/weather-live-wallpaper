import Foundation
import WeatherKit
import QuartzCore
import Darwin

@_silgen_name("call_swift_init")
func swiftInit(_ function: UnsafeRawPointer, _ metadata: UnsafeRawPointer) -> UnsafeRawPointer
@_silgen_name("call_swift_method")
func swiftMethod(_ function: UnsafeRawPointer, _ object: UnsafeRawPointer, _ args: UnsafePointer<UInt>, _ result: UnsafeMutableRawPointer?)

@_silgen_name("call_swift_moon")
func swiftMoon(_ function:UnsafeRawPointer,_ object:UnsafeRawPointer,_ date:UnsafeRawPointer,_ zone:UnsafeRawPointer,_ result:UnsafeMutableRawPointer,_ latitude:Double,_ longitude:Double)

@objc(WeatherRuntime) class WeatherRuntime: NSObject {
 // Rendering updates run on the main thread; preserve the previous configuration
 // so solar updates don't restart every weather layer as a new location.
 static var previousEffect:ObjectIdentifier?
 static var previousConfiguration:Any?
 // These are runtime types from the installed OS, not replacement definitions.
 // Field descriptors let us construct their values without hardcoding Swift layouts.
 static let handle = dlopen("/System/iOSSupport/System/Library/PrivateFrameworks/WeatherUI.framework/WeatherUI",RTLD_NOW)!
 static func resolve(_ name:UnsafeRawPointer,_ length:UInt,_ context:UnsafeRawPointer?,_ args:UnsafeRawPointer?)->Any.Type? {
  let fn=unsafeBitCast(dlsym(dlopen(nil,RTLD_NOW),"swift_getTypeByMangledNameInContext")!,to:(@convention(c)(UnsafeRawPointer,UInt,UnsafeRawPointer?,UnsafeRawPointer?)->UnsafeRawPointer?).self)
  return fn(name,length,context,args).map {unsafeBitCast($0,to:Any.Type.self)}
 }
 static func symbol(_ name: String) -> UnsafeRawPointer { UnsafeRawPointer(dlsym(handle,name)!) }
 static func type(_ name: String) -> Any.Type {
  let p=unsafeBitCast(symbol(name),to:(@convention(c)(UInt)->UnsafeRawPointer).self)(0)
  return unsafeBitCast(p,to:Any.Type.self)
 }
 static func fields(_ type: Any.Type) -> [(String,Int,Any.Type)] {
  let p=unsafeBitCast(type,to:UnsafeRawPointer.self)
  let desc=p.load(fromByteOffset:8,as:UnsafeRawPointer.self)
  let fields=desc.advanced(by:16+Int(desc.load(fromByteOffset:16,as:Int32.self)))
  let count=Int(desc.load(fromByteOffset:20,as:UInt32.self))
  let vector=Int(desc.load(fromByteOffset:24,as:UInt32.self))*8
  let stride=Int(fields.load(fromByteOffset:10,as:UInt16.self))
  return (0..<count).map { i in
   let r=fields.advanced(by:16+i*stride)
   let name=r.advanced(by:8+Int(r.load(fromByteOffset:8,as:Int32.self)))
   let mangled=r.advanced(by:4+Int(r.load(fromByteOffset:4,as:Int32.self)))
   var n=0
   while true { let c=mangled.load(fromByteOffset:n,as:UInt8.self); if c==0 {break}; n+=1; if c>=1 && c<=0x17 {n+=4} else if c>=0x18 && c<=0x1f {n+=8} }
   return (String(cString:name.assumingMemoryBound(to:CChar.self)),Int(p.load(fromByteOffset:vector+4*i,as:UInt32.self)),resolve(mangled,UInt(n),desc,p.advanced(by:16))!)
  }
 }
 static func read(_ type: Any.Type, _ p:UnsafeRawPointer) -> Any {
  func load<T>(_ t:T.Type)->Any {p.assumingMemoryBound(to:T.self).pointee}
  return _openExistential(type,do:load)
 }
 static func store(_ value:Any, _ p:UnsafeMutableRawPointer) {
  func write<T>(_ v:T) {p.assumingMemoryBound(to:T.self).initialize(to:v)}
  _openExistential(value,do:write)
 }
 static func none(_ optionalType:Any.Type)->Any {
  let p=unsafeBitCast(optionalType,to:UnsafeRawPointer.self)
  let wrapped=unsafeBitCast(p.load(fromByteOffset:16,as:UnsafeRawPointer.self),to:Any.Type.self)
  func make<T>(_ type:T.Type)->Any {Optional<T>.none as Any}
  return _openExistential(wrapped,do:make)
 }
 static func enumValue(_ type:Any.Type,_ name:String)->Any {
  let p=unsafeBitCast(type,to:UnsafeRawPointer.self)
  let desc=p.load(fromByteOffset:8,as:UnsafeRawPointer.self)
  precondition(desc.load(fromByteOffset:20,as:UInt32.self)&0xffffff==0,"Payload enum unsupported")
  let f=desc.advanced(by:16+Int(desc.load(fromByteOffset:16,as:Int32.self)))
  let stride=Int(f.load(fromByteOffset:10,as:UInt16.self))
  let count=Int(f.load(fromByteOffset:12,as:UInt32.self))
  for i in 0..<count {
   let r=f.advanced(by:16+i*stride+8)
   let str=r.advanced(by:Int(r.load(as:Int32.self)))
   if String(cString:str.assumingMemoryBound(to:CChar.self))==name {
    var tag=UInt64(i); return withUnsafePointer(to:&tag) {read(type,$0)}
   }
  }
  fatalError("Unknown case \(type).\(name)")
 }
 static func decode(_ type:any Decodable.Type,_ json:String) throws -> Any {
  func inner<T:Decodable>(_ t:T.Type) throws -> Any {try JSONDecoder().decode(t,from:Data(json.utf8))}
  return try _openExistential(type,do:inner)
 }
 final class Buffer {
  let type:Any.Type
  let pointer:UnsafeMutableRawPointer
  var ownsValues=true
  init(_ type:Any.Type,_ values:[String:Any]) {
   self.type=type;pointer = .allocate(byteCount:16384,alignment:64)
   pointer.initializeMemory(as:UInt8.self,repeating:0,count:16384)
   for(name,offset,t) in fields(type) {
    guard let value=values[name] else {fatalError("Missing field \(name)")}
    precondition(String(reflecting:t)==String(reflecting:Swift.type(of:value)),"Field type mismatch: \(name)")
    store(value,pointer.advanced(by:offset))
   }
  }
  deinit {
   func destroy<T>(_ t:T.Type) {pointer.assumingMemoryBound(to:T.self).deinitialize(count:1)}
   if ownsValues {_openExistential(type,do:destroy)};pointer.deallocate()
  }
 }
 static func object(_ stem:String)->AnyObject {
  let t=type(stem+"CMa")
  let p=swiftInit(symbol(stem+"CACycfC"),unsafeBitCast(t,to:UnsafeRawPointer.self))
  return Unmanaged<AnyObject>.fromOpaque(p).takeRetainedValue()
 }
 static func call(_ name:String,_ object:AnyObject,_ args:[UInt],_ result:UnsafeMutableRawPointer?) {
  args.withUnsafeBufferPointer {swiftMethod(symbol(name),Unmanaged.passUnretained(object).toOpaque(),$0.baseAddress!,result)}
 }
 static func optionalType(_ type:Any.Type)->Any.Type {
  func make<T>(_ t:T.Type)->Any.Type {Optional<T>.self}
  return _openExistential(type,do:make)
 }
 static func optionalSome(_ value:Any)->Any {
  func make<T>(_ v:T)->Any {Optional.some(v) as Any}
  return _openExistential(value,do:make)
 }
 @objc static func isSupported() -> Bool {
  guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 else {return false}
  return ["$s9WeatherUI16MoonDataProviderCACycfC","$s9WeatherUI18BackgroundMoonDataVMa","$s9WeatherUI16MoonDataProviderC017weatherBackgroundcD03for8timeZone10coordinateAA0gcD0VSg10Foundation4DateV_AK04TimeJ0VSo22CLLocationCoordinate2DVtF","$s9WeatherUI21SkyBackgroundGradientV5apply2toySo15CAGradientLayerC_tF","$s9WeatherUI0A12VFXViewModelVMa","$s9WeatherUI0A7VFXViewVMa","$s9WeatherUI0A7VFXViewV5model24foregroundEffectsEnabledAcA0aC5ModelV_SbtcfC","$s9WeatherUI0A7VFXViewV10makeUIView7contextSo0C0C05SwiftB00E20RepresentableContextVyACG_tF","$s9WeatherUI0A27ConditionConfigurationModelVMa","$s9WeatherUI0A25ConditionBackgroundConfigVMa","$s9WeatherUI0A22ConditionGradientModelVMa","$s9WeatherUI0A29ConditionConfigurationManagerCACycfC","$s9WeatherUI0A24ConditionGradientManagerCACycfC","$s9WeatherUI0A9VFXEffectC9vfxEffectAC3VFX0C0C_tcfC"].allSatisfy { (name:String) in name.withCString { dlsym(handle,$0) != nil } }
 }
 @objc static func makeView(_ effect:AnyObject)->AnyObject {
  let modelType=type("$s9WeatherUI0A12VFXViewModelVMa")
  let modeType=fields(modelType).first {$0.0=="resizingMode"}!.2
  var modeStorage:UInt64=0
  let mode=withUnsafePointer(to:&modeStorage){read(modeType,$0)}
  let model=Buffer(modelType,["effect":optionalSome(effect),"scaleFactor":CGFloat(1),"preferredFramesPerSecond":60,"resizingMode":mode])
  let viewType=type("$s9WeatherUI0A7VFXViewVMa")
  let result=UnsafeMutableRawPointer.allocate(byteCount:16384,alignment:64)
  defer {result.deallocate()}
  let args=[UInt(bitPattern:model.pointer),0,0,0,0,0]
  args.withUnsafeBufferPointer {swiftMethod(symbol("$s9WeatherUI0A7VFXViewV5model24foregroundEffectsEnabledAcA0aC5ModelV_SbtcfC"),unsafeBitCast(viewType,to:UnsafeRawPointer.self),$0.baseAddress!,result)}
  // The view initializer moves its model argument into the resulting value.
  model.ownsValues=false
  let value=read(viewType,result)
  func destroy<T>(_ t:T.Type){result.assumingMemoryBound(to:T.self).deinitialize(count:1)}
  _openExistential(viewType,do:destroy)
  func make<T>(_ value:T)->AnyObject {
   withUnsafePointer(to:value){ pointer in
    // The inspected implementation doesn't read the SwiftUI context argument
    // when foreground effects are disabled. Keep Apple's complete view setup.
    let object=swiftInitArgument(symbol("$s9WeatherUI0A7VFXViewV10makeUIView7contextSo0C0C05SwiftB00E20RepresentableContextVyACG_tF"),pointer,0)
    return Unmanaged<AnyObject>.fromOpaque(object).takeRetainedValue()
   }
  }
  return _openExistential(value,do:make)
 }
 @objc static func applyEffect(_ effect:AnyObject, condition:String, elevation:Double, cloudCover:Double, wind:Double, size:CGSize, isPM:Bool, timeZone:String) -> NSDictionary {
  applyEffect(effect,condition:condition,elevation:elevation,cloudCover:cloudCover,wind:wind,size:size,isPM:isPM,timeZone:timeZone,details:[:])
 }
 @objc static func applyEffect(_ effect:AnyObject, condition:String, elevation:Double, cloudCover:Double, wind:Double, size:CGSize, isPM:Bool, timeZone:String, details:NSDictionary) -> NSDictionary {
  let renderDate=(details["date"] as? Double).map {Date(timeIntervalSince1970:$0)} ?? Date()
  let conditions:[String:WeatherCondition]=["clear":.clear,"mostlyClear":.mostlyClear,"partlyCloudy":.partlyCloudy,"mostlyCloudy":.mostlyCloudy,"cloudy":.cloudy,"rain":.rain,"heavyRain":.heavyRain,"drizzle":.drizzle,"thunderstorms":.thunderstorms,"snow":.snow,"heavySnow":.heavySnow,"foggy":.foggy,"hail":.hail,"freezingRain":.freezingRain,"freezingDrizzle":.freezingDrizzle,"windy":.windy]
  guard let weather=conditions[condition] else {return ["error":"Condição desconhecida"]}
  let modelType=type("$s9WeatherUI0A27ConditionConfigurationModelVMa")
  let schema=fields(modelType)
  func ft(_ name:String)->Any.Type {schema.first {$0.0==name}!.2}
  let elevationValue=Buffer(ft("elevation"),["degrees":CGFloat(elevation),"isPM":isPM])
  // Use WeatherUI's own altitude classifier, including its tie-breaking rules.
  let cloudBuffer=UnsafeMutableRawPointer.allocate(byteCount:16,alignment:16)
  defer {cloudBuffer.deallocate()}
  swiftCloudKind(symbol("$s9WeatherUI17CloudAltitudeKindO3low3mid4highACSd_S2dtcfC"),cloudBuffer,
   (details["cloudLow"] as? Double) ?? cloudCover,(details["cloudMid"] as? Double) ?? 0,(details["cloudHigh"] as? Double) ?? 0)
  let altitude=read(ft("cloudKind"),cloudBuffer)
  var values:[String:Any]=[
   "condition":weather,"windSpeed":Measurement(value:wind,unit:UnitSpeed.kilometersPerHour),
   "cloudCover":cloudCover,"cloudKind":altitude,
   "elevation":read(ft("elevation"),elevationValue.pointer),"date":renderDate,"timeZone":TimeZone(identifier:timeZone) ?? .current,
   "cameraPositionType":enumValue(ft("cameraPositionType"),"default"),
   "dynamicTypeSize":enumValue(ft("dynamicTypeSize"),"large"),
   "targetWindowSizeClass":enumValue(ft("targetWindowSizeClass"),size.width >= size.height ? "landscapeRegular" : "portraitRegular"),
   "displayLocation":enumValue(ft("displayLocation"),"locationViewer"),"nativeScreenSize":size]
  for name in ["sunrise","sunset","moonData","collisionViewMetrics"] {values[name]=none(ft(name))}
  for name in ["sunrise","sunset"] {
   if let timestamp=details[name] as? Double {values[name]=Optional.some(Date(timeIntervalSince1970:timestamp)) as Any}
  }
  var moonDescription="unavailable"
  if let latitude=details["latitude"] as? Double,let longitude=details["longitude"] as? Double {
   let provider=object("$s9WeatherUI16MoonDataProvider")
   let moonType=optionalType(type("$s9WeatherUI18BackgroundMoonDataVMa"))
   let moonResult=UnsafeMutableRawPointer.allocate(byteCount:4096,alignment:64)
   defer {moonResult.deallocate()}
   let date=renderDate
   let zone=TimeZone(identifier:timeZone) ?? .current
   withUnsafePointer(to:date){d in withUnsafePointer(to:zone){z in
    swiftMoon(symbol("$s9WeatherUI16MoonDataProviderC017weatherBackgroundcD03for8timeZone10coordinateAA0gcD0VSg10Foundation4DateV_AK04TimeJ0VSo22CLLocationCoordinate2DVtF"),Unmanaged.passUnretained(provider).toOpaque(),d,z,moonResult,latitude,longitude)
   }}
   values["moonData"]=read(moonType,moonResult)
   moonDescription=String(describing:values["moonData"]!)
   func destroyMoon<T>(_ t:T.Type){moonResult.assumingMemoryBound(to:T.self).deinitialize(count:1)}
   _openExistential(moonType,do:destroyMoon)
  }
  let model=Buffer(modelType,values)
  let manager=object("$s9WeatherUI0A29ConditionConfigurationManager")
  let result=UnsafeMutableRawPointer.allocate(byteCount:16384,alignment:64)
  defer {result.deallocate()}
  call("$s9WeatherUI0A29ConditionConfigurationManagerC4load3forAA0aC16BackgroundConfigVSgAA0acD5ModelV_tF",manager,[UInt(bitPattern:model.pointer),0,0,0,0,0],result)
  let configType=type("$s9WeatherUI0A25ConditionBackgroundConfigVMa")
  let configOptionalType=optionalType(configType)
  let optional=read(configOptionalType,result)
  // Balance the initialized indirect return after copying it into Swift ownership.
  func destroy<T>(_ t:T.Type) {result.assumingMemoryBound(to:T.self).deinitialize(count:1)}
  _openExistential(configOptionalType,do:destroy)
  guard var config=Mirror(reflecting:optional).children.first?.value else {return ["error":"No configuration for this condition"]}

  // Calibrate the original star emitters for a full desktop. Tune a fresh config
  // before applyUpdate so repeated solar refreshes never compound attenuation.
  var starValues=Dictionary(uniqueKeysWithValues:Mirror(reflecting:config).children.compactMap { child -> (String,Any)? in child.label.map {($0,child.value)} })
  for key in ["starParticleCount","starBrightParticleCount"] {
   if let count=starValues[key] as? Int {starValues[key]=Int((Double(count) * (key=="starParticleCount" ? 0.55 : 0.30)).rounded())}
  }
  for (key,multiplier) in [("starOpacity",Float(0.65)),("starTwinkleAmount",0.50),("starBrightTwinkleAmount",0.40)] {
   if let value=starValues[key] as? Float {starValues[key]=value * multiplier}
  }
  for key in ["starSize","starBrightSize"] {
   if let value=starValues[key] as? SIMD2<Float> {starValues[key]=value * (key=="starSize" ? 0.82 : 0.65)}
  }
  // Apple's location-viewer composition can place the solar flare outside a
  // desktop's crop. Reframe its original emitter into the upper sky.
  if elevation>0, ["clear","mostlyClear","partlyCloudy"].contains(condition),let sun=starValues["sunRayStartPosition"] as? SIMD3<Float> {
   starValues["sunRayPositionFollowsTimeOfDay"]=false
   starValues["sunRayStartPosition"]=SIMD3<Float>(max(-18,min(18,sun.x*0.32)),16+Float(min(elevation,65)/65)*4,sun.z)
  }
  let desktopConfig=Buffer(configType,starValues)
  config=read(configType,desktopConfig.pointer)

  let gradientType=type("$s9WeatherUI0A22ConditionGradientModelVMa")
  let gs=fields(gradientType)
  let presentationType=gs.first {$0.0=="presentation"}!.2
  let presentation=try! decode(presentationType as! any Decodable.Type,"{\"fullScreen\":{\"_0\":{\"vfx\":{}}}}")
  let gradientModel=Buffer(gradientType,["conditionKind":weather,"elevation":values["elevation"]!,"isDaylight":(details["isDaylight"] as? Bool) ?? (elevation > -0.833),"presentation":presentation,"cloudCover":cloudCover,"cloudKind":values["cloudKind"]!])
  let gm=object("$s9WeatherUI0A24ConditionGradientManager")
  let gradientResult=UnsafeMutableRawPointer.allocate(byteCount:4096,alignment:64)
  defer {gradientResult.deallocate()}
  call("$s9WeatherUI0A24ConditionGradientManagerC4load3forAA013SkyBackgroundD0VAA0acD5ModelV_tF",gm,[UInt(bitPattern:gradientModel.pointer),0,0,0,0,0],gradientResult)
  let skyType=type("$s9WeatherUI21SkyBackgroundGradientVMa")
  let sky=read(skyType,gradientResult)

  func destroySky<T>(_ t:T.Type) {gradientResult.assumingMemoryBound(to:T.self).deinitialize(count:1)}
  _openExistential(skyType,do:destroySky)
  let wrapperType=type("$s9WeatherUI0A9VFXEffectCMa")
  // Swift's allocating initializer consumes an owned effect argument.
  let wrapperArgs=[UInt(bitPattern:Unmanaged.passRetained(effect).toOpaque()),0,0,0,0,0]
  let wrapperPointer=wrapperArgs.withUnsafeBufferPointer { args -> UnsafeRawPointer in
   // Allocating Swift initializer returns the retained object in x0.
   let fn=symbol("$s9WeatherUI0A9VFXEffectC9vfxEffectAC3VFX0C0C_tcfC")
   return swiftInitArgument(fn,unsafeBitCast(wrapperType,to:UnsafeRawPointer.self),args[0])
  }
  let wrapper=Unmanaged<AnyObject>.fromOpaque(wrapperPointer).takeRetainedValue()
  func withValue<T,R>(_ value:T,_ body:(UnsafeRawPointer)->R)->R {withUnsafePointer(to:value) {body($0)}}
  let effectKind=UnsafeMutableRawPointer.allocate(byteCount:16,alignment:16)
  let cameraKind=UnsafeMutableRawPointer.allocate(byteCount:16,alignment:16)
  defer {effectKind.deallocate();cameraKind.deallocate()}
  store(enumValue(type("$s9WeatherUI13VFXEffectTypeOMa"),"background"),effectKind)
  store(values["cameraPositionType"]!,cameraKind)
  let sameEffect=previousEffect == ObjectIdentifier(effect)
  let lastConfig=(sameEffect ? previousConfiguration : nil).map {optionalSome($0)} ?? none(configOptionalType)
  let optionalSky=optionalSome(sky)
  func invoke<C>(_ cfg:C) {
   func last<L>(_ previous:L) {
    func grad<G>(_ gradient:G) {
     withValue(cfg) { c in withValue(previous) { l in withValue(gradient) { g in
      // Effect/camera enums are resilient: pass pointers, not integer tags.
      call("$s9WeatherUI0A9VFXEffectC11applyUpdate_17lastConfiguration10effectType014cameraPositionI018hasLocationChanged8gradientyAA0A25ConditionBackgroundConfigV_AKSgAA0cI0OAK06CamerakI0OSbAA03SkyQ8GradientVSgtF",wrapper,[UInt(bitPattern:c),UInt(bitPattern:l),UInt(bitPattern:effectKind),UInt(bitPattern:cameraKind),sameEffect ? 0 : 1,UInt(bitPattern:g)],nil)
     } } }
    }
    _openExistential(optionalSky,do:grad)
   }
   _openExistential(lastConfig,do:last)
  }
  _openExistential(config,do:invoke)
  let background=CAGradientLayer()
  func applyGradient<G>(_ gradient:G) {
   withUnsafePointer(to:gradient) {p in
    let args=[UInt(bitPattern:Unmanaged.passUnretained(background).toOpaque()),0,0,0,0,0]
    args.withUnsafeBufferPointer {swiftMethod(symbol("$s9WeatherUI21SkyBackgroundGradientV5apply2toySo15CAGradientLayerC_tF"),p,$0.baseAddress!,nil)}
   }
  }
  _openExistential(sky,do:applyGradient)
  previousEffect=ObjectIdentifier(effect);previousConfiguration=config
  return ["condition":condition,"elevation":elevation,"renderer":"Apple WeatherUI + VFX", "configuration":"Apple original", "cloudKind":String(describing:altitude),"gradientLayer":background,"moonData":moonDescription,"sunPosition":String(describing:starValues["sunRayStartPosition"]!),"sunAlpha":(starValues["sunSpikeBallColor"] as? SIMD4<Float>)?.w ?? 0,"moonImage":starValues["moonImageName"]!,"starCount":starValues["starParticleCount"]!,"brightStarCount":starValues["starBrightParticleCount"]!,"starOpacity":starValues["starOpacity"]!]
 }
}

@_silgen_name("call_swift_init_argument")
func swiftInitArgument(_ function:UnsafeRawPointer,_ metadata:UnsafeRawPointer,_ arg:UInt)->UnsafeRawPointer

@_silgen_name("call_swift_cloud_kind")
func swiftCloudKind(_ function:UnsafeRawPointer,_ result:UnsafeMutableRawPointer,_ low:Double,_ mid:Double,_ high:Double)
