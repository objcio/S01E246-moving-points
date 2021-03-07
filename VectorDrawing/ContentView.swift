//
//  ContentView.swift
//  VectorDrawing
//
//  Created by Chris Eidhof on 22.02.21.
//

import SwiftUI

extension Path {
    var elements: [Element] {
        var result: [Element] = []
        forEach { result.append($0) }
        return result
    }
}

extension Path.Element: Identifiable { // hack
    public var id: String { "\(self)" }
}

struct PathPoint: View {
    @Binding var element: Drawing.Element
    
    func pathPoint(at: CGPoint) -> some View {
        Circle()
            .stroke(Color.black)
            .background(Circle().fill(Color.white))
            .padding(2)
            .frame(width: 14, height: 14)
            .offset(x: at.x-7, y: at.y-7)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { state in
                        element.move(to: state.location)
                    }
            )
    }

    func controlPoint(at: CGPoint) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(Color.black)
            .background(RoundedRectangle(cornerRadius: 2).fill(Color.white))
            .padding(4)
            .frame(width: 14, height: 14)
            .offset(x: at.x-7, y: at.y-7)
    }

    var body: some View {
        if let cp = element.controlPoints {
            Path { p in
                p.move(to: cp.0)
                p.addLine(to: element.point)
                p.addLine(to: cp.1)
            }.stroke(Color.gray)
            controlPoint(at: cp.0)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { state in
                            element.moveControlPoint1(to: state.location)
                        }
                )
            controlPoint(at: cp.1)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { state in
                            element.moveControlPoint2(to: state.location)
                        }
                )
        }
        pathPoint(at: element.point)
    }
}

struct Points: View {
    @Binding var drawing: Drawing
    var body: some View {
        ForEach(Array(zip(drawing.elements, drawing.elements.indices)), id: \.0.id) { element in
            PathPoint(element: $drawing.elements[element.1])
        }
    }
}

struct Drawing {
    var elements: [Element] = []
    
    struct Element: Identifiable {
        let id = UUID()
        var point: CGPoint
        var secondaryPoint: CGPoint?
    }
}

extension Drawing.Element {
    var controlPoints: (CGPoint, CGPoint)? {
        guard let s = secondaryPoint else { return nil }
        return (s.mirrored(relativeTo: point), s)
    }
    
    mutating func move(to: CGPoint) {
        let diff = to - point
        point = to
        secondaryPoint = secondaryPoint.map { $0 + diff }
    }
    
    mutating func moveControlPoint1(to: CGPoint) {
        secondaryPoint = to.mirrored(relativeTo: point)
    }
    
    mutating func moveControlPoint2(to: CGPoint) {
        secondaryPoint = to
    }
}

extension Drawing {
    var path: Path {
        var result = Path()
        guard let f = elements.first else { return result }
        result.move(to: f.point)
        var previousControlPoint: CGPoint? = nil
        
        for element in elements.dropFirst() {
            if let previousCP = previousControlPoint {
                let cp2 = element.controlPoints?.0 ?? element.point
                result.addCurve(to: element.point, control1: previousCP, control2: cp2)
            } else {
                if let mirrored = element.controlPoints?.0 {
                    result.addQuadCurve(to: element.point, control: mirrored)
                } else {
                    result.addLine(to: element.point)
                }
            }
            previousControlPoint = element.secondaryPoint
        }
        return result
    }
}

extension Drawing {
    mutating func update(for state: DragGesture.Value) {
        let isDrag = state.startLocation.distance(to: state.location) > 1
        elements.append(Element(point: state.startLocation, secondaryPoint: isDrag ? state.location : nil))
    }
}

struct DrawingView: View {
    @State var drawing = Drawing()
    @GestureState var currentDrag: DragGesture.Value? = nil
    
    var liveDrawing: Drawing {
        var copy = drawing
        if let state = currentDrag {
            copy.update(for: state)
        }
        return copy
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            liveDrawing.path.stroke(Color.black, lineWidth: 2)
            Points(drawing: Binding(get: { liveDrawing }, set: { drawing = $0 }))
        }.gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .updating($currentDrag, body: { (value, state, _) in
                    state = value
                })
                .onEnded { state in
                    drawing.update(for: state)
                }
        )
    }
}

struct ContentView: View {
    var body: some View {
        DrawingView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
