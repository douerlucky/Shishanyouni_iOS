//
//  shishanyouniApp.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/4.
//

import SwiftUI

@main
struct shishanyouniApp: App
{
    @StateObject private var userinfo = userInfo()
    
    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
            .environmentObject(userinfo)
        }
    }
}
