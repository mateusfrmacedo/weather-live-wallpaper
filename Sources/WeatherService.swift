import Foundation

@objc(WeatherService) class WeatherService:NSObject {
 static func json(_ url:URL,completion:@escaping(Any?,String?)->Void) {
  var request=URLRequest(url:url);request.timeoutInterval=20
  URLSession.shared.dataTask(with:request) {data,response,error in
   guard let http=response as? HTTPURLResponse,(200..<300).contains(http.statusCode),let data else {completion(nil,error?.localizedDescription ?? "O serviço de clima não respondeu.");return}
   do {completion(try JSONSerialization.jsonObject(with:data),nil)} catch {completion(nil,"Resposta de clima inválida.")}
  }.resume()
 }
 @objc static func search(_ query:String,completion:@escaping([NSDictionary]?,String?)->Void) {
  var url=URLComponents(string:"https://geocoding-api.open-meteo.com/v1/search")!
  url.queryItems=[URLQueryItem(name:"name",value:query),URLQueryItem(name:"count",value:"5"),URLQueryItem(name:"language",value:"pt"),URLQueryItem(name:"format",value:"json")]
  json(url.url!) {object,error in
   let results=(object as? [String:Any])?["results"] as? [NSDictionary]
   DispatchQueue.main.async {completion(results,error)}
  }
 }
 @objc static func fetch(_ location:NSDictionary,completion:@escaping(NSDictionary?,String?)->Void) {
  guard let lat=location["latitude"] as? Double,let lon=location["longitude"] as? Double else {completion(nil,"Cidade inválida.");return}
  var url=URLComponents(string:"https://api.open-meteo.com/v1/forecast")!
  url.queryItems=[.init(name:"latitude",value:String(lat)),.init(name:"longitude",value:String(lon)),.init(name:"current",value:"temperature_2m,is_day,weather_code,cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high,wind_speed_10m"),.init(name:"daily",value:"sunrise,sunset"),.init(name:"timeformat",value:"unixtime"),.init(name:"timezone",value:"auto"),.init(name:"forecast_days",value:"1")]
  json(url.url!) {object,error in
   guard let root=object as? [String:Any],let current=root["current"] as? [String:Any],let code=current["weather_code"] as? Int,let temp=current["temperature_2m"] as? Double,let cover=current["cloud_cover"] as? Double,let wind=current["wind_speed_10m"] as? Double else {DispatchQueue.main.async {completion(nil,error ?? "Dados de clima incompletos.")};return}
   let condition:String
   switch code {
   case 0:condition="clear"
   case 1:condition="mostlyClear"
   case 2:condition="partlyCloudy"
   case 3:condition="cloudy"
   case 45,48:condition="foggy"
   case 51,53,55:condition="drizzle"
   case 56,57:condition="freezingDrizzle"
   case 61,63,80,81:condition="rain"
   case 65,82:condition="heavyRain"
   case 66,67:condition="freezingRain"
   case 71,73,77,85:condition="snow"
   case 75,86:condition="heavySnow"
   case 95:condition="thunderstorms"
   case 96,99:condition="hail"
   default:condition="cloudy"
   }
   let now=Date()
   var output:[String:Any]=["condition":condition,"temperature":temp,"cloudCover":cover/100,"wind":wind,"elevation":solarElevation(latitude:lat,longitude:lon,date:now),"isPM":isPM(longitude:lon,date:now),"timeZone":root["timezone"] as? String ?? "UTC","updatedAt":now.timeIntervalSince1970]
   for (input,key) in [("cloud_cover_low","cloudLow"),("cloud_cover_mid","cloudMid"),("cloud_cover_high","cloudHigh")] {
    if let value=current[input] as? Double {output[key]=value/100}
   }
   if let isDay=current["is_day"] as? Int {output["isDaylight"]=isDay == 1}
   if let daily=root["daily"] as? [String:Any] {
    for key in ["sunrise","sunset"] {if let times=daily[key] as? [Double],let first=times.first {output[key]=first}}
   }
   let weather=output as NSDictionary
   DispatchQueue.main.async {completion(weather,nil)}
  }
 }
 static func isPM(longitude:Double,date:Date)->Bool {
  let hour=(date.timeIntervalSince1970.truncatingRemainder(dividingBy:86400)/3600+longitude/15+24).truncatingRemainder(dividingBy:24)
  return hour >= 12
 }
 @objc static func lightingForLocation(_ location:NSDictionary)->NSDictionary {
  guard let lat=location["latitude"] as? Double,let lon=location["longitude"] as? Double else {return [:]}
  let now=Date()
  return ["elevation":solarElevation(latitude:lat,longitude:lon,date:now),"isPM":isPM(longitude:lon,date:now)]
 }
 static func solarElevation(latitude:Double,longitude:Double,date:Date)->Double {
  var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!
  let day=Double(calendar.ordinality(of:.day,in:.year,for:date) ?? 1)
  let hour=Double(calendar.component(.hour,from:date))+Double(calendar.component(.minute,from:date))/60
  let g=2*Double.pi/365*(day-1+(hour-12)/24)
  let decl=0.006918-0.399912*cos(g)+0.070257*sin(g)-0.006758*cos(2*g)+0.000907*sin(2*g)-0.002697*cos(3*g)+0.00148*sin(3*g)
  let eq=229.18*(0.000075+0.001868*cos(g)-0.032077*sin(g)-0.014615*cos(2*g)-0.040849*sin(2*g))
  let angle=(hour*60+eq+4*longitude)/4-180
  let rad=Double.pi/180
  return asin(min(1,max(-1,sin(latitude*rad)*sin(decl)+cos(latitude*rad)*cos(decl)*cos(angle*rad))))/rad
 }
}
