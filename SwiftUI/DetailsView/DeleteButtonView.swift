//
//  DeleteButtonView.swift
//  School_ToDoList-SUI
//
//  Created by Roman Tverdokhleb on 21.07.2023.
//

import SwiftUI

struct DeleteButtonView: View {
    @Binding var presentSheet: Bool
    var isEnableForOld: Bool
    
    var body: some View {
        GeometryReader { geometry in
            Button {
                presentSheet.toggle()
            } label: {
                ZStack {
                    Rectangle()
                        .frame(width: geometry.size.width * 0.915, height: 56)
                        .foregroundColor(Color("BackSecondary"))
                        .cornerRadius(15)
                        .padding()
                    if isEnableForOld {
                        Text("Delete")
                            .foregroundColor(Color("Red"))
                            .padding(.vertical)
                    } else {
                        Text("Delete")
                            .foregroundColor(Color("LabelTertiary"))
                            .padding(.vertical)
                    }
                    
                }
            }
            .disabled(!isEnableForOld)
        }
    }
}
