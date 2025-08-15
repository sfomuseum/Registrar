import UIKit

class KeyValueTableViewCell: UITableViewCell {

    let keyLabel = UILabel()
    var valueLabel = UILabel()

    // Optional property for editable text field
    var editableTextField: UITextField?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        // Add labels to the cell's content view
        contentView.addSubview(keyLabel)
        contentView.addSubview(valueLabel)

        // Set up constraints for key and value labels
        setupConstraints()
        
        keyLabel.font = UIFont.boldSystemFont(ofSize: valueLabel.font.pointSize)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        // Add labels to the cell's content view
        contentView.addSubview(keyLabel)
        contentView.addSubview(valueLabel)

        // Set up constraints for key and value labels
        setupConstraints()
        
        keyLabel.font = UIFont.boldSystemFont(ofSize: valueLabel.font.pointSize)
    }

    private func setupConstraints() {
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Key label on the left, with padding from leading edge
            keyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            keyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            keyLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            // Value label on the right, with padding from trailing edge
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: keyLabel.trailingAnchor, constant: 8), // Ensure it doesn't overlap
            valueLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            valueLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            // Add width constraint to the value label to allow wrapping
            valueLabel.widthAnchor.constraint(lessThanOrEqualToConstant: contentView.bounds.width - keyLabel.frame.maxX - 16) // Adjust as needed
        ])
    }
}
