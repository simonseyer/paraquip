//
//  ProfileListView.swift
//  ProfileListView
//
//  Created by Simon Seyer on 26.08.21.
//

import SwiftUI
import CoreData

struct ProfileListView: View {

    @FetchRequest(sortDescriptors: [SortDescriptor(\.name)])
    private var profiles: FetchedResults<Profile>

    @State private var editProfileOperation: Operation<Profile>?

    @Environment(\.managedObjectContext) var managedObjectContext

    var body: some View {
        List {
            Section {
                ForEach(profiles) { profile in
                    NavigationLink {
                        ProfileView(profile: profile)
                    } label: {
                        HStack {
                            Image(profile.profileIcon.rawValue)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.accentColor)
                                .frame(width: 35, height: 35)
                                .padding(.trailing, 8)

                            Text(profile.profileName)
                        }
                    }
                    .padding([.top, .bottom])
                    .swipeActions {
                        Button {
                            editProfileOperation = Operation(editing: profile,
                                                             withParentContext: managedObjectContext)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            withAnimation {
                                managedObjectContext.delete(profile)
                                try! managedObjectContext.save()
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .labelStyle(.titleOnly)
                }
            } footer: {
                Text("set_footer")
            }
        }
        .navigationTitle("All Sets")
        .sheet(item: $editProfileOperation) { operation in
            NavigationView {
                EditProfileView(profile: operation.object)
                    .environment(\.managedObjectContext, operation.childContext)
                    .onDisappear {
                        try? managedObjectContext.save()
                    }
            }
        }
        .interactiveDismissDisabled(true)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editProfileOperation = Operation(withParentContext: managedObjectContext)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {

    static var previews: some View {
        NavigationView {
            ProfileListView()
                .environment(\.managedObjectContext, CoreData.previewContext)
        }
    }
}
