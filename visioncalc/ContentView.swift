import SwiftUI
import Combine

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var model = CalculatorModel()

    // параметры размера
    private let buttonSize: CGFloat = 80
    private let spacing: CGFloat = 12

    var body: some View {
        ZStack {
            Color.black.opacity(0.02)
                .ignoresSafeArea()

            VStack(spacing: spacing) {
                // Display — теперь такая же ширина, как у ряда кнопок
                Text(model.display)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .frame(width: buttonSize * 4 + spacing * 3, height: buttonSize)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06)))

                // Buttons grid
                VStack(spacing: spacing) {
                    ForEach(ButtonLayout.rows, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(row, id: \.self) { key in
                                CalculatorButton(
                                    key: key,
                                    size: buttonSize,
                                    spacing: spacing,
                                    action: { handle(key) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .preferredColorScheme(.dark)
    }

    private func handle(_ key: CalcKey) {
        switch key {
        case .digit(let d): model.appendDigit(d)
        case .decimal: model.appendDecimal()
        case .op(let op): model.choose(operation: op)
        case .equals: model.calculate()
        case .clear: model.clear()
        case .plusMinus: model.toggleSign()
        case .percent: model.percent()
        }
    }
}

// MARK: - Button view
struct CalculatorButton: View {
    let key: CalcKey
    let size: CGFloat
    let spacing: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(key.title)
                .font(.system(size: 26, weight: .medium, design: .rounded))
                .frame(
                    width: key == .digit(0) ? size * 2 + spacing : size,
                    height: size
                )
                .background(key.background)
                .foregroundColor(key.foreground)
                .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Model (без изменений)
final class CalculatorModel: ObservableObject {
    @Published private(set) var display: String = "0"

    private var current: Decimal = 0
    private var stored: Decimal? = nil
    private var currentOperation: Operation? = nil
    private var userTyping = false
    private var hasDecimal = false

    func appendDigit(_ d: Int) {
        if !userTyping {
            display = ""
            userTyping = true
        }
        if display == "0" && d == 0 { return }
        display += String(d)
        updateCurrentFromDisplay()
    }

    func appendDecimal() {
        if !userTyping {
            display = "0"
            userTyping = true
        }
        if hasDecimal { return }
        display += "."
        hasDecimal = true
    }

    func choose(operation: Operation) {
        if userTyping { updateCurrentFromDisplay() }
        if let s = stored, let op = currentOperation {
            stored = perform(op, s, current)
        } else {
            stored = current
        }
        currentOperation = operation
        userTyping = false
        hasDecimal = false
        display = formatDecimal(stored ?? 0)
    }

    func calculate() {
        guard let op = currentOperation, let s = stored else { return }
        updateCurrentFromDisplay()
        let result = perform(op, s, current)
        display = formatDecimal(result)
        stored = nil
        currentOperation = nil
        current = result
        userTyping = false
        hasDecimal = false
    }

    func clear() {
        current = 0
        stored = nil
        currentOperation = nil
        userTyping = false
        hasDecimal = false
        display = "0"
    }

    func toggleSign() {
        updateCurrentFromDisplay()
        current *= -1
        display = formatDecimal(current)
    }

    func percent() {
        updateCurrentFromDisplay()
        current = current / 100
        display = formatDecimal(current)
    }

    private func updateCurrentFromDisplay() {
        let sanitized = display.replacingOccurrences(of: ",", with: ".")
        current = Decimal(string: sanitized) ?? 0
    }

    private func formatDecimal(_ d: Decimal) -> String {
        let ns = NSDecimalNumber(decimal: d)
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .decimal
        return formatter.string(from: ns) ?? "0"
    }

    private func perform(_ op: Operation, _ a: Decimal, _ b: Decimal) -> Decimal {
        switch op {
        case .add: return a + b
        case .subtract: return a - b
        case .multiply: return a * b
        case .divide:
            return b == 0 ? 0 : a / b
        }
    }
}

// MARK: - Operation & Keys
enum Operation {
    case add, subtract, multiply, divide
}

enum CalcKey: Hashable {
    case digit(Int)
    case decimal
    case op(Operation)
    case equals
    case clear
    case plusMinus
    case percent

    var title: String {
        switch self {
        case .digit(let d): return String(d)
        case .decimal: return "."
        case .op(.add): return "+"
        case .op(.subtract): return "−"
        case .op(.multiply): return "×"
        case .op(.divide): return "÷"
        case .equals: return "="
        case .clear: return "C"
        case .plusMinus: return "±"
        case .percent: return "%"
        }
    }

    var background: some View {
        Group {
            switch self {
            case .op, .equals:
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06))
            case .clear, .plusMinus, .percent:
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04))
            default:
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.02))
            }
        }
    }

    var foreground: Color {
        switch self {
        case .op, .equals: return Color.primary
        default: return Color.primary.opacity(0.9)
        }
    }
}

// MARK: - Layout
struct ButtonLayout {
    static let rows: [[CalcKey]] = [
        [.clear, .plusMinus, .percent, .op(.divide)],
        [.digit(7), .digit(8), .digit(9), .op(.multiply)],
        [.digit(4), .digit(5), .digit(6), .op(.subtract)],
        [.digit(1), .digit(2), .digit(3), .op(.add)],
        [.digit(0), .decimal, .equals]
    ]
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewLayout(.sizeThatFits)
    }
}
