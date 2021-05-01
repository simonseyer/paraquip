//
//  ParagliderPersistenceMapping.swift
//  Paraquip
//
//  Created by Simon Seyer on 01.05.21.
//

import Foundation

extension Paraglider {
    func toPersistence() -> PersistedParaglider {
        return PersistedParaglider(
            id: id,
            brand: brand,
            name: name,
            size: size,
            checkCycle: checkCycle,
            checkLog: checkLog.map { $0.toPersistence() }
        )
    }
}

extension PersistedParaglider {
    func toModel() -> Paraglider {
        return Paraglider(
            id: id,
            brand: brand,
            name: name,
            size: size,
            checkCycle: checkCycle,
            checkLog: checkLog.map { $0.toModel() } )
    }
}
