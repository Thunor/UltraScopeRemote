//
//  View+NavTitleColor.swift
//  RobotRemote
//
//  Created by Eric Freitas on 7/26/26.
//

// Source - https://stackoverflow.com/a/66050825
// Posted by cliss, modified by community. See post 'Timeline' for change history
// Retrieved 2026-07-26, License - CC BY-SA 4.0

import SwiftUI

extension View {
    /// Sets the text color for a navigation bar title.
    /// - Parameter color: Color the title should be
    ///
    /// Supports both regular and large titles.
    @available(iOS 14, *)
    func navigationBarTitleTextColor(_ color: Color) -> some View {
        let uiColor = UIColor(color)
    
        // Set appearance for both normal and large sizes.
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: uiColor ]
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: uiColor ]
    
        return self
    }
}
