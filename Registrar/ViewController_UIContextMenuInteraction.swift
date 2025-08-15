import UIKit

extension ViewController: UIContextMenuInteractionDelegate {
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        
        if let im_interaction = interaction as? ImageMenuInteraction  {
            return self.imageMenuInteraction(im_interaction, configurationForMenuAtLocation: location)
        }
        
        if let tv_interaction = interaction as? TableValueMenuInteraction  {
            return self.tableValueMenuInteraction(tv_interaction, configurationForMenuAtLocation: location)
        }
        
        print("Unsupported menu interaction")
        
        return nil
    }
    
    private func imageMenuInteraction(_ im_interaction: ImageMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        
        guard let indexPath = im_interaction.indexPath else {
            return nil
        }
        
        guard let row = im_interaction.row else {
            return nil
        }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash")) { action in
                self.images.remove(at: row)
                self.collectionView.deleteItems(at: [indexPath])
            }
            
            return UIMenu(title: "", children: [deleteAction])
        }
    }
    
    private func tableValueMenuInteraction(_ tv_interaction: TableValueMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
            
            guard let indexPath = tv_interaction.indexPath else {
                return nil
            }
            
            guard let row = tv_interaction.row else {
                return nil
            }
            
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
                
                let editAction = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { action in

                    let (key, value) = self.keyValuePairs[indexPath.row]
                    self.editValueDialog(key: key, value: value)
                }
                
                return UIMenu(title: "", children: [editAction])
            }
    }
    
    private func editValueDialog(key: String, value: String ) {
        
        let alertController = UIAlertController(title: "Edit \(key)", message: nil, preferredStyle: .alert)

                alertController.addTextField { textField in
                    textField.text = value
                }

                let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
                    if let newValue = alertController.textFields?.first?.text {

                        guard let this = self else {
                            return
                        }
                            
                        if !this.label.setProperty(key: key, value: newValue){
                            this.showAlert(title: "Unable to update \(key)", message: "There was a problem updating the value of \(key)")
                            return
                        }
                        
                        this.updateTableData(label: this.label)
                    }
                }

                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

                alertController.addAction(saveAction)
                alertController.addAction(cancelAction)

                if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                    rootVC.present(alertController, animated: true, completion: nil)
                }
    }
}
