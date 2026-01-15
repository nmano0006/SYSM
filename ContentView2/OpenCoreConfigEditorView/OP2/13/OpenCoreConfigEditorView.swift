private func generateEntriesFromValue(value: Any, key: String, parentKey: String?, isOpenCoreSpecific: Bool) -> [ConfigEntry] {
    var entries: [ConfigEntry] = []
    
    if let dict = value as? [String: Any] {
        // For dictionaries, create entries for each key-value pair
        addDebugLog("  Dictionary '\(key)' with \(dict.count) items")
        
        // First, add a header entry for the dictionary itself
        if key != selectedSection { // Don't add header for top-level sections
            entries.append(ConfigEntry(
                key: key,
                type: "Dictionary",
                value: "\(dict.count) items",
                isEnabled: true,
                actualValue: dict,
                isOpenCoreSpecific: isOpenCoreSpecific,
                parentKey: parentKey
            ))
        }
        
        // Then add entries for each key-value pair
        for (subKey, subValue) in dict.sorted(by: { $0.key < $1.key }) {
            let fullKey = parentKey != nil ? "\(parentKey!).\(subKey)" : subKey
            entries.append(contentsOf: generateEntriesFromValue(
                value: subValue,
                key: subKey,
                parentKey: key == selectedSection ? nil : fullKey, // Don't nest top-level section entries
                isOpenCoreSpecific: isOpenCoreSpecific
            ))
        }
    } else if let array = value as? [Any] {
        // For arrays, create entries
        addDebugLog("  Array '\(key)' with \(array.count) items")
        
        let type = "Array"
        let valueString = "\(array.count) items"
        
        entries.append(ConfigEntry(
            key: key,
            type: type,
            value: valueString,
            isEnabled: true,
            actualValue: array,
            isOpenCoreSpecific: isOpenCoreSpecific,
            parentKey: parentKey
        ))
        
        // Show first 3 items for preview
        for (index, item) in array.prefix(3).enumerated() {
            let itemKey = "\(key)[\(index)]"
            let fullKey = parentKey != nil ? "\(parentKey!).\(itemKey)" : itemKey
            entries.append(contentsOf: generateEntriesFromValue(
                value: item,
                key: itemKey,
                parentKey: fullKey,
                isOpenCoreSpecific: isOpenCoreSpecific
            ))
        }
        
        if array.count > 3 {
            entries.append(ConfigEntry(
                key: "\(key)[3+]",
                type: "Array Items",
                value: "... \(array.count - 3) more items",
                isEnabled: true,
                actualValue: nil,
                isOpenCoreSpecific: isOpenCoreSpecific,
                parentKey: parentKey
            ))
        }
    } else {
        // For primitive values
        let type = getTypeString(for: value)
        let valueString = getValueString(for: value, type: type)
        let isEnabled = type == "Boolean" ? (value as? Bool ?? false) : true
        
        addDebugLog("  Primitive '\(key)': \(valueString) (\(type))")
        
        entries.append(ConfigEntry(
            key: key,
            type: type,
            value: valueString,
            isEnabled: isEnabled,
            actualValue: value,
            isOpenCoreSpecific: isOpenCoreSpecific,
            parentKey: parentKey
        ))
    }
    
    return entries
}