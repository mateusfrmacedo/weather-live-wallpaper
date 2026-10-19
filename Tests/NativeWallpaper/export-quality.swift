import Foundation
import AVFoundation
import ImageIO
import CoreMedia

@main struct ExportQuality {
 static func main() async throws {
  let root=URL(fileURLWithPath:"/Users/Shared/WeatherWallpaper/\(getuid())",isDirectory:true)
  let data=try Data(contentsOf:root.appendingPathComponent("current.json"))
  let manifest=try JSONSerialization.jsonObject(with:data) as! [String:Any]
  let folder=root.appendingPathComponent(manifest["generation"] as! String,isDirectory:true)
  let source=CGImageSourceCreateWithURL(folder.appendingPathComponent("poster.png") as CFURL,nil)!
  let poster=CGImageSourceCreateImageAtIndex(source,0,nil)!
  let asset=AVURLAsset(url:folder.appendingPathComponent("sky.mov"))
  let duration=try await asset.load(.duration)
  guard (16...17).contains(CMTimeGetSeconds(duration)) else {fatalError("Animation duration mismatch")}
  let tracks=try await asset.loadTracks(withMediaType:.video)
  let track=tracks.first!
  let size=try await track.load(.naturalSize)
  let descriptions=try await track.load(.formatDescriptions)
  guard let width=manifest["pixelWidth"] as? Int,let height=manifest["pixelHeight"] as? Int,
        let pointsW=manifest["renderWidth"] as? Double,let pointsH=manifest["renderHeight"] as? Double,
        let backing=manifest["renderScale"] as? Double else {fatalError("Missing pixel geometry")}
  let scale=min(1,5120/max(pointsW*backing,pointsH*backing))
  let expectedW=Int(floor(pointsW*backing*scale/2))*2,expectedH=Int(floor(pointsH*backing*scale/2))*2
  guard width==expectedW,height==expectedH,poster.width==width,poster.height==height,
        Int(size.width)==width,Int(size.height)==height,
        descriptions.contains(where:{CMFormatDescriptionGetMediaSubType($0)==kCMVideoCodecType_HEVC})
        else {fatalError("Retina geometry, poster or codec mismatch")}
  print("PASS: physical display pixels preserved (\(width)x\(height)), matching PNG and HEVC movie")
  if ["clear","mostlyClear"].contains(manifest["condition"] as? String ?? ""),
     (manifest["elevation"] as? Double ?? 0)<(-10) {
   var pixels=[UInt8](repeating:0,count:width*height*4)
   let contrast=pixels.withUnsafeMutableBytes { bytes -> (Double,Double) in
    let context=CGContext(data:bytes.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
      space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue|CGBitmapInfo.byteOrder32Big.rawValue)!
    context.draw(poster,in:CGRect(x:0,y:0,width:width,height:height))
    let data=bytes.bindMemory(to:UInt8.self)
    func luminance(_ x:Int,_ y:Int)->Double {let p=(y*width+x)*4;return (Double(data[p])+Double(data[p+1])+Double(data[p+2]))/3}
    func stars(_ lower:Double,_ upper:Double)->Double {
     var samples=[Double]()
     // The left side excludes the Moon; local contrast removes the sky gradient.
     for y in Int(Double(height)*lower)..<Int(Double(height)*upper) {
      for x in max(8,width/20)..<min(width-8,width*45/100) {
       samples.append(luminance(x,y)-(luminance(x-8,y)+luminance(x+8,y))/2)
      }
     }
     samples.sort();return samples[Int(Double(samples.count-1)*0.999)]
    }
    return (stars(0.05,0.30),stars(0.75,0.95))
   }
   guard contrast.0>5,contrast.1<contrast.0*0.4 else {fatalError("Stars do not fade toward the bottom of the exported image")}
   print("PASS: exported night stars fade toward the horizon, with correct mask orientation")
  }
 }
}
