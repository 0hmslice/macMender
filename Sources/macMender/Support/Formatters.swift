import Foundation

extension Double {
    var sliderValueLabel: String {
        String(format: "%.2f", self)
    }

    var wholeNumberLabel: String {
        String(format: "%.0f", self)
    }
}
