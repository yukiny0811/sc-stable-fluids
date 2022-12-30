//
//  ContentView.swift
//  FluidSimSwift
//
//  Created by Yuki Kuwashima on 2022/12/27.
//

import SwiftUI
import SwiftyCreatives

struct ContentView: View {
    @State var dt: Float = 0.01
    @State var diffusion: Float = 0.001
    let sketch = FluidSketch()
    var body: some View {
        HStack {
            SketchView<MyCameraConfig, MainDrawConfig>(sketch)
                .frame(width: 500, height: 500)
            VStack {
                Group {
                    Text("dt: \(dt)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Slider(value: $dt, in: 0.000001...0.1) { _ in
                        sketch.dt = dt
                    }
                }
                Group {
                    Text("diffusion: \(diffusion)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Slider(value: $diffusion, in: 0.000001...0.1) { _ in
                        sketch.diffusion = diffusion
                    }
                }
            }
            .padding(30)
            .frame(width: 300, height: 500)
        }
        .background(Color(nsColor: NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)))
    }
}

final class MyCameraConfig: CameraConfigBase {
    static var fov: Float = MainCameraConfig.fov
    static var near: Float = MainCameraConfig.near
    static var far: Float = MainCameraConfig.far
    static var polarSpacing: Float = MainCameraConfig.polarSpacing
    static var enableEasyMove: Bool = false
}

final class FluidSketch: SketchBase {
    
    init() {
        for i in 0..<num {
            velocity.append(f2(0, 0))
            prevVelocity.append(f2(0, 0))
            density.append(0)
            prevDensity.append(0)
            
            let rect = Box()
            let x: Float = Float(i % FluidSketch.COUNTp2) - Float(FluidSketch.COUNTp2/2)
            let y: Float = Float(Int(i / FluidSketch.COUNTp2)) - Float(FluidSketch.COUNTp2/2)
            rect.setPos(f3(x, y, 0))
            rect.setColor(f4.randomPoint(0...1))
            rect.setScale(f3.one * 0.5)
            rectArray.append(rect)
        }
    }
    
    var velocity: [f2] = []
    var prevVelocity: [f2] = []
    
    var density: [Float] = []
    var prevDensity: [Float] = []
    
    var rectArray: [Box] = []
    
    static let COUNT = 30
    static let COUNTp1 = COUNT + 1
    static let COUNTp2 = COUNT + 2
    
    var dt: Float = 0.01
    var diffusion: Float = 0.001
    let num: Int = (COUNTp2)*(COUNTp2)
    let inputSize: Float = 5.0
    
    var saveMouse = f2(0, 0)
    
    var isDragging: Bool = false
    
    func setupCamera(camera: some SwiftyCreatives.MainCameraBase) {
        camera.setTranslate(0, 0, -30)
        camera.setRotation(-0.8, 0.0, 0)
    }
    
    func update(camera: some SwiftyCreatives.MainCameraBase) {
        fluidUpdate()
        
        for r in 0..<rectArray.count {
//            rectArray[r].setColor(f4(density[r], abs(velocity[r].x), abs(velocity[r].y), 1))
            rectArray[r].setColor(f4(density[r], density[r], density[r], 1))
            rectArray[r].setPos(f3(rectArray[r].pos.x, rectArray[r].pos.y, abs(velocity[r].x) - abs(velocity[r].y)))
        }
    }
    
    func draw(encoder: MTLRenderCommandEncoder) {
        for r in rectArray {
            r.draw(encoder)
        }
    }
    
    func mouseDown(with event: NSEvent, camera: some MainCameraBase, viewFrame: CGRect) {
        let rawLocation = event.locationInWindow
        let location: f2 = f2(Float(rawLocation.x), Float(rawLocation.y))
        saveMouse = location
    }
    
    func mouseDragged(with event: NSEvent, camera: some MainCameraBase, viewFrame: CGRect) {
        let rawLocation = CGPoint(
            x: event.locationInWindow.x - viewFrame.origin.x,
            y: event.locationInWindow.y - viewFrame.origin.y
        )
        let location: f2 = f2(Float(rawLocation.x), Float(rawLocation.y))
        
        let diff = location - saveMouse
        saveMouse = location
        
        for i in 0..<num {
            prevVelocity[i] = f2(0, 0)
            prevDensity[i] = 0
        }
        
        let processedX = Int(location.x / (Float(viewFrame.width) / Float(FluidSketch.COUNT)))
        let processedY = Int(location.y / (Float(viewFrame.height) / Float(FluidSketch.COUNT)))
        
        let mainIndex = getPos(processedX, processedY)
        
        let size = 1
        
        if processedX < 0 || processedX > FluidSketch.COUNTp2 || processedY < 0 || processedY > FluidSketch.COUNTp2 {
            return
        }
        
        for x in processedX-size...processedX+size {
            for y in processedY-size...processedY+size {
                if x < 0 || x > FluidSketch.COUNTp2 || y < 0 || y > FluidSketch.COUNTp2 {
                    continue
                }
                let index = getPos(x, y)
                prevDensity[index] = 100
            }
        }
        prevVelocity[mainIndex] = f2(diff.x * 1000, diff.y * 1000)
        
        isDragging = true
    }
    
    func mouseUp(with event: NSEvent, camera: some MainCameraBase, viewFrame: CGRect) {
        isDragging = false
    }
    
    func addSourceVec(_ current: inout [f2], _ prev: inout [f2], dt: Float) {
        for i in 0..<num {
            current[i] += prev[i] * dt
        }
    }
    
    func addSourceFloat(_ current: inout [Float], _ prev: inout [Float], dt: Float) {
        for i in 0..<num {
            current[i] += prev[i] * dt
        }
    }
    
    func getPos(_ x: Int, _ y: Int) -> Int {
        return y * FluidSketch.COUNTp2 + x
    }
    
    func setBoundaryFloat(_ current: inout [Float], side: Int) {
        for i in 1..<FluidSketch.COUNTp1 {
            current[getPos(0, i)] = side == 1 ? -current[getPos(1, i)] : current[getPos(1, i)]
            current[getPos(FluidSketch.COUNTp1, i)] = side == 1 ? -current[getPos(FluidSketch.COUNT, i)] : current[getPos(FluidSketch.COUNT, i)]
            current[getPos(i, 0)] = side == 2 ? -current[getPos(i, 1)] : current[getPos(i, 1)]
            current[getPos(i, FluidSketch.COUNTp1)] = side == 2 ? -current[getPos(i, FluidSketch.COUNT)] : current[getPos(i, FluidSketch.COUNT)]
        }
        current[getPos(0, 0)] = 0.5 * (current[getPos(1, 0)] + current[getPos(0, 1)])
        current[getPos(0, FluidSketch.COUNTp1)] = 0.5 * (current[getPos(1, FluidSketch.COUNTp1)] + current[getPos(0, FluidSketch.COUNT)])
        current[getPos(FluidSketch.COUNTp1, 0)] = 0.5 * (current[getPos(FluidSketch.COUNT, 0)] + current[getPos(FluidSketch.COUNTp1, 1)])
        current[getPos(FluidSketch.COUNTp1, FluidSketch.COUNTp1)] = 0.5 * (current[getPos(FluidSketch.COUNT, FluidSketch.COUNTp1)] + current[getPos(FluidSketch.COUNTp1, FluidSketch.COUNT)])
    }
    
    func setBoundaryVec(_ current: inout [f2], side: Int) {
        if side == 1 {
            for i in 1..<FluidSketch.COUNTp1 {
                current[getPos(0, i)].x = -current[getPos(1, i)].x
                current[getPos(FluidSketch.COUNTp1, i)].x = -current[getPos(FluidSketch.COUNT, i)].x
                current[getPos(i, 0)].x = current[getPos(i, 1)].x
                current[getPos(i, FluidSketch.COUNTp1)].x = current[getPos(i, FluidSketch.COUNT)].x
            }
            current[getPos(0, 0)].x = 0.5 * (current[getPos(1, 0)].x + current[getPos(0, 1)].x)
            current[getPos(0, FluidSketch.COUNTp1)].x = 0.5 * (current[getPos(1, FluidSketch.COUNTp1)].x + current[getPos(0, FluidSketch.COUNT)].x)
            current[getPos(FluidSketch.COUNTp1, 0)].x = 0.5 * (current[getPos(FluidSketch.COUNT, 0)].x + current[getPos(FluidSketch.COUNTp1, 1)].x)
            current[getPos(FluidSketch.COUNTp1, FluidSketch.COUNTp1)].x = 0.5 * (current[getPos(FluidSketch.COUNT, FluidSketch.COUNTp1)].x + current[getPos(FluidSketch.COUNTp1, FluidSketch.COUNT)].x)
        } else if side == 2 {
            for i in 1..<FluidSketch.COUNTp1 {
                current[getPos(0, i)].y = current[getPos(1, i)].y
                current[getPos(FluidSketch.COUNTp1, i)].y = current[getPos(FluidSketch.COUNT, i)].y
                current[getPos(i, 0)].y = -current[getPos(i, 1)].y
                current[getPos(i, FluidSketch.COUNTp1)].y = -current[getPos(i, FluidSketch.COUNT)].y
            }
            current[getPos(0, 0)].y = 0.5 * (current[getPos(1, 0)].y + current[getPos(0, 1)].y)
            current[getPos(0, FluidSketch.COUNTp1)].y = 0.5 * (current[getPos(1, FluidSketch.COUNTp1)].y + current[getPos(0, FluidSketch.COUNT)].y)
            current[getPos(FluidSketch.COUNTp1, 0)].y = 0.5 * (current[getPos(FluidSketch.COUNT, 0)].y + current[getPos(FluidSketch.COUNTp1, 1)].y)
            current[getPos(FluidSketch.COUNTp1, FluidSketch.COUNTp1)].y = 0.5 * (current[getPos(FluidSketch.COUNT, FluidSketch.COUNTp1)].y + current[getPos(FluidSketch.COUNTp1, FluidSketch.COUNT)].y)
        } else {
            for i in 1..<FluidSketch.COUNTp1 {
                current[getPos(0, i)] = side == 1 ? -current[getPos(1, i)] : current[getPos(1, i)]
                current[getPos(FluidSketch.COUNTp1, i)] = side == 1 ? -current[getPos(FluidSketch.COUNT, i)] : current[getPos(FluidSketch.COUNT, i)]
                current[getPos(i, 0)] = side == 2 ? -current[getPos(i, 1)] : current[getPos(i, 1)]
                current[getPos(i, FluidSketch.COUNTp1)] = side == 2 ? -current[getPos(i, FluidSketch.COUNT)] : current[getPos(i, FluidSketch.COUNT)]
            }
            current[getPos(0, 0)] = 0.5 * (current[getPos(1, 0)] + current[getPos(0, 1)])
            current[getPos(0, FluidSketch.COUNTp1)] = 0.5 * (current[getPos(1, FluidSketch.COUNTp1)] + current[getPos(0, FluidSketch.COUNT)])
            current[getPos(FluidSketch.COUNTp1, 0)] = 0.5 * (current[getPos(FluidSketch.COUNT, 0)] + current[getPos(FluidSketch.COUNTp1, 1)])
            current[getPos(FluidSketch.COUNTp1, FluidSketch.COUNTp1)] = 0.5 * (current[getPos(FluidSketch.COUNT, FluidSketch.COUNTp1)] + current[getPos(FluidSketch.COUNTp1, FluidSketch.COUNT)])
        }
    }
    
    func diffuseFloat(_ current: inout [Float], _ prev: inout [Float], diffusionAmount: Float, dt: Float) {
        let iter = 20
        let amount: Float = dt * diffusionAmount * Float(FluidSketch.COUNT * FluidSketch.COUNT)
        for _ in 0..<iter {
            for y in 1..<FluidSketch.COUNTp1 {
                for x in 1..<FluidSketch.COUNTp1 {
                    current[getPos(x, y)] = (
                        prev[getPos(x, y)] + amount * (
                            current[getPos(x-1, y)] +
                            current[getPos(x+1, y)] +
                            current[getPos(x, y-1)] +
                            current[getPos(x, y+1)]
                        )
                    ) / (1 + 4*amount)
                    
                    
                    
                }
            }
            setBoundaryFloat(&current, side: 0)
        }
    }
    
    func diffuseVec(_ current: inout [f2], _ prev: inout [f2], diffusionAmount: Float, dt: Float) {
        let iter = 20
        let amount: Float = dt * diffusionAmount * Float(FluidSketch.COUNT * FluidSketch.COUNT)
        for _ in 0..<iter {
            for y in 1..<FluidSketch.COUNTp1 {
                for x in 1..<FluidSketch.COUNTp1 {
                    current[getPos(x, y)] = (
                        prev[getPos(x, y)] + amount * (
                            current[getPos(x-1, y)] +
                            current[getPos(x+1, y)] +
                            current[getPos(x, y-1)] +
                            current[getPos(x, y+1)]
                        )
                    ) / (1 + 4*amount)
                }
            }
            setBoundaryVec(&current, side: 1)
            setBoundaryVec(&current, side: 2)
        }
    }
    
    func advect(_ currentDensity: inout [Float], _ prevDensity: inout [Float], currentVelocity: inout [f2], dt: Float) {
        let dt0: Float = dt * Float(FluidSketch.COUNT)
        for x in 1..<FluidSketch.COUNTp1 {
            for y in 1..<FluidSketch.COUNTp1 {
                var tempX: Float = Float(x) - dt0 * currentVelocity[getPos(x, y)].x
                var tempY: Float = Float(y) - dt0 * currentVelocity[getPos(x, y)].y
                
                if tempX < 0.5 { tempX = 0.5 }
                if tempX > Float(FluidSketch.COUNT) + 0.5 { tempX = Float(FluidSketch.COUNT) + 0.5 }
                let x0 = Int(floor(tempX))
                let x1 = x0 + 1
                
                if tempY < 0.5 { tempY = 0.5 }
                if tempY > Float(FluidSketch.COUNT) + 0.5 { tempY = Float(FluidSketch.COUNT) + 0.5 }
                let y0 = Int(floor(tempY))
                let y1 = y0 + 1
                
                let s1 = tempX - Float(x0)
                let s0 = 1.0 - s1
                let t1 = tempY - Float(y0)
                let t0 = 1.0 - t1
                
                currentDensity[getPos(x, y)] = s0 * (
                    t0 * prevDensity[getPos(x0, y0)] + t1 * prevDensity[getPos(x0, y1)]
                ) + s1 * (
                    t0 * prevDensity[getPos(x1, y0)] + t1 * prevDensity[getPos(x1, y1)]
                )
            }
        }
        setBoundaryFloat(&currentDensity, side: 0)
    }
    
    func advectVel(_ currentVelocity: inout [f2], _ prevVelocity: inout [f2], dt: Float) {
        let dt0: Float = dt * Float(FluidSketch.COUNT)
        for x in 1..<FluidSketch.COUNTp1 {
            for y in 1..<FluidSketch.COUNTp1 {
                var tempX: Float = Float(x) - dt0 * prevVelocity[getPos(x, y)].x
                var tempY: Float = Float(y) - dt0 * prevVelocity[getPos(x, y)].y
                
                if tempX < 0.5 { tempX = 0.5 }
                if tempX > Float(FluidSketch.COUNT) + 0.5 { tempX = Float(FluidSketch.COUNT) + 0.5 }
                let x0 = Int(floor(tempX))
                let x1 = x0 + 1
                
                if tempY < 0.5 { tempY = 0.5 }
                if tempY > Float(FluidSketch.COUNT) + 0.5 { tempY = Float(FluidSketch.COUNT) + 0.5 }
                let y0 = Int(floor(tempY))
                let y1 = y0 + 1
                
                let s1 = tempX - Float(x0)
                let s0 = 1.0 - s1
                let t1 = tempY - Float(y0)
                let t0 = 1.0 - t1
                
                currentVelocity[getPos(x, y)].x = s0 * (
                    t0 * prevVelocity[getPos(x0, y0)].x + t1 * prevVelocity[getPos(x0, y1)].x
                ) + s1 * (
                    t0 * prevVelocity[getPos(x1, y0)].x + t1 * prevVelocity[getPos(x1, y1)].x
                )
                
                currentVelocity[getPos(x, y)].y = s0 * (
                    t0 * prevVelocity[getPos(x0, y0)].y + t1 * prevVelocity[getPos(x0, y1)].y
                ) + s1 * (
                    t0 * prevVelocity[getPos(x1, y0)].y + t1 * prevVelocity[getPos(x1, y1)].y
                )
            }
        }
        setBoundaryVec(&currentVelocity, side: 1);
        setBoundaryVec(&currentVelocity, side: 2);
    }
    
    func project(_ currentVelocity: inout [f2], _ prevVelocity: inout [f2]) {
        let h: Float = 1.0 / Float(FluidSketch.COUNT)
        for x in 1..<FluidSketch.COUNTp1 {
            for y in 1..<FluidSketch.COUNTp1 {
                prevVelocity[getPos(x, y)].y = -0.5 * h * (
                    currentVelocity[getPos(x+1, y)].x -
                    currentVelocity[getPos(x-1, y)].x +
                    currentVelocity[getPos(x, y+1)].y -
                    currentVelocity[getPos(x, y-1)].y
                )
                prevVelocity[getPos(x, y)].x = 0
            }
        }
        setBoundaryVec(&prevVelocity, side: 0)
        
        for _ in 0..<20 {
            for x in 1..<FluidSketch.COUNTp1 {
                for y in 1..<FluidSketch.COUNTp1 {
                    prevVelocity[getPos(x, y)].x =  (
                        prevVelocity[getPos(x, y)].y +
                        prevVelocity[getPos(x-1, y)].x +
                        prevVelocity[getPos(x+1, y)].x +
                        prevVelocity[getPos(x, y-1)].x +
                        prevVelocity[getPos(x, y+1)].x
                    ) / 4.0
                }
            }
            setBoundaryVec(&prevVelocity, side: 0)
        }
        for x in 1..<FluidSketch.COUNTp1 {
            for y in 1..<FluidSketch.COUNTp1 {
                currentVelocity[getPos(x, y)].x -= 0.5 * (
                    prevVelocity[getPos(x+1, y)].x - prevVelocity[getPos(x-1, y)].x
                ) / h
                currentVelocity[getPos(x, y)].y -= 0.5 * (
                    prevVelocity[getPos(x, y+1)].x - prevVelocity[getPos(x, y-1)].x
                ) / h
            }
        }
        setBoundaryVec(&currentVelocity, side: 1)
        setBoundaryVec(&currentVelocity, side: 2)
    }
    
    func velocityStep() {
        addSourceVec(&velocity, &prevVelocity, dt: dt)
        swap(&velocity, &prevVelocity)
        diffuseVec(&velocity, &prevVelocity, diffusionAmount: diffusion, dt: dt)
        project(&velocity, &prevVelocity)
        swap(&velocity, &prevVelocity)
        advectVel(&velocity, &prevVelocity, dt: dt)
        project(&velocity, &prevVelocity)
    }
    
    func densityStep() {
        addSourceFloat(&density, &prevDensity, dt: dt)
        swap(&density, &prevDensity)
        diffuseFloat(&density, &prevDensity, diffusionAmount: diffusion, dt: dt)
        swap(&density, &prevDensity)
        advect(&density, &prevDensity, currentVelocity: &velocity, dt: dt)
    }
    
    func fluidUpdate() {
        if !isDragging {
            for i in 0..<num {
                prevVelocity[i] = f2.zero
                prevDensity[i] = 0
            }
        }
        velocityStep()
        densityStep()
    }
}
