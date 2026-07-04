extension Array {
    /// Returns the element at `index`, or `nil` when it is out of bounds.
    ///
    /// Single module-internal definition; individual files previously kept
    /// their own file-private copies of this helper.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
