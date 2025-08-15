import UIKit

extension ViewController: UIContextMenuInteractionDelegate {
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        
        guard let im_interaction = interaction as? ImageMenuInteraction else {
            return nil
        }
        
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
}
