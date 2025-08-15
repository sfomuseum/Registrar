import UIKit

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    
    func updateTableData(label: WallLabel) {
        
        clearTable()
        
        // START OF put me in a function... maybe?
        
        let dict = propertiesToDictionary(instance: label)
        
        var newKeyValuePairs: [(String, String)] = []
        
        for key in label.displayKeys() {
            
            if !dict.keys.contains(key){
                continue
            }
            
            let value = dict[key]
            
            if let stringValue = value as? String {
                newKeyValuePairs.append((key, stringValue))
            } else if let numberValue = value as? NSNumber {
                newKeyValuePairs.append((key, "\(numberValue)"))
            }
        }
        
        // END OF put me in a function
        
        keyValuePairs = newKeyValuePairs
        tableView.reloadData()
    }
    

    func clearTable() {
        let numberOfRows = keyValuePairs.count
        var indexPathsToDelete = [IndexPath]()
        
        for row in 0..<numberOfRows {
            let indexPath = IndexPath(row: row, section: 0)
            indexPathsToDelete.append(indexPath)
        }
        
        keyValuePairs.removeAll()
        tableView.deleteRows(at: indexPathsToDelete, with: .automatic)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return keyValuePairs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "KeyValueCell", for: indexPath) as? KeyValueTableViewCell else {
            return UITableViewCell()
        }
        
        let (key, value) = keyValuePairs[indexPath.row]
        
        cell.keyLabel.text = key
        
        cell.keyLabel.text = key
        cell.valueLabel.text = value

        cell.valueLabel.numberOfLines = 0
        cell.valueLabel.lineBreakMode = .byWordWrapping
            
        let interaction = TableValueMenuInteraction(delegate: self)
        interaction.indexPath = indexPath
        interaction.row = indexPath.row
        
        cell.addInteraction(interaction)
        
        return cell
    }
    
    func isKeyEditable(key: String) -> Bool {
        
        return false
        
        switch (key) {
        case "title", "date", "creator", "medium", "location", "creditline":
            return true
        default:
            return false
        }
    }
    
    func propertiesToDictionary<T: Codable>(instance: T) -> [String: Any] {
        var dictionary = [String: Any]()
        
        let mirror = Mirror(reflecting: instance)
        for child in mirror.children {
            if let propertyName = child.label {
                dictionary[propertyName] = child.value
            }
        }
        
        return dictionary
    }
    
    func setupEditableTextField(cell: KeyValueTableViewCell) {
        let textField = UITextField()
        textField.text = cell.valueLabel.text

        // Apply other desired settings for your text field (e.g., font, placeholder)
        textField.font = UIFont.boldSystemFont(ofSize: 16)

        // Configure the constraints to replace valueLabel with textField
        cell.contentView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            textField.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            textField.centerYAnchor.constraint(equalTo: cell.keyLabel.centerYAnchor),

            // Set width constraint for text field to allow wrapping
            textField.widthAnchor.constraint(lessThanOrEqualToConstant: cell.contentView.bounds.width - 32)
        ])

        cell.valueLabel.isHidden = true

        // Add target to handle text changes
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

        cell.editableTextField = textField
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        guard let cell = getCellForTextField(textField),
              let indexPath = tableView.indexPath(for: cell) else { return }

        // Update the keyValuePairs array with the new value from the text field
        var mutableKeyValuePairs = keyValuePairs
        mutableKeyValuePairs[indexPath.row].1 = textField.text ?? ""
        keyValuePairs = mutableKeyValuePairs

        // Optionally, update your data source or perform any other action needed
    }

    func getCellForTextField(_ textField: UITextField) -> KeyValueTableViewCell? {
        if let superview = textField.superview?.superview as? UITableViewCell,
           let cell = superview as? KeyValueTableViewCell {
            return cell
        }
        return nil
    }
    
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
