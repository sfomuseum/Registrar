import UIKit

extension ViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath)
        
        cell.layer.borderColor = UIColor.black.cgColor
        cell.layer.borderWidth = 2
        
        if let imageView = cell.viewWithTag(100) as? UIImageView {
            imageView.image = images[indexPath.row]
            
            let interaction = ImageMenuInteraction(delegate: self)
            interaction.indexPath = indexPath
            interaction.row = indexPath.row
            
            cell.addInteraction(interaction)
        }
        
        return cell
        
    }
}
