import UIKit

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    
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
        cell.valueLabel.text = value
        
        cell.valueLabel.numberOfLines = 0
        cell.valueLabel.lineBreakMode = .byWordWrapping
        
        if isKeyEditable(key: key) {
            let interaction = TableValueMenuInteraction(delegate: self)
            interaction.indexPath = indexPath
            interaction.row = indexPath.row
            cell.addInteraction(interaction)
        }
        
        /*
        if indexPath.row+1 == keyValuePairs.count{
            print("DONE")
            let ex = self.exportTable()
            print("EX \(ex)")
        }
        */
        
        return cell
    }
    
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
    
    func exportTable() -> [String: String] {
        var result = [String: String]()
        
        for indexPath in 0..<tableView.numberOfRows(inSection: 0) {
            guard let cell = tableView.cellForRow(at: IndexPath(row: indexPath, section: 0)) as? KeyValueTableViewCell else {
                continue
            }
            
            if let key = cell.keyLabel.text, let value = cell.valueLabel.text {
                result[key] = value
            }
        }
        
        return result
    }
    
    func isKeyEditable(key: String) -> Bool {
        
        switch (key) {
        case "title", "date", "creator", "medium", "location", "creditline", "accession_number":
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
}
