//
//  Kettlebell_ForceApp.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import SwiftUI
import CoreData

@main
struct Kettlebell_ForceApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
