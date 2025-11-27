//
//  SettingsView.swift
//  ConDict
//
//  Created by Jack Davenport on 11/26/25.
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @AppStorage("appTheme") private var appTheme: String = "System"
    @AppStorage("selectedVoiceID") private var selectedVoiceID: String = ""
    @AppStorage("selectedFont") private var selectedFont: String = "System"
    
    var body: some View {
        TabView {
            GeneralSettingsView(appTheme: $appTheme, selectedVoiceID: $selectedVoiceID, selectedFont: $selectedFont)
                .tabItem { Label("General", systemImage: "gear") }
            
            DeveloperSettingsView()
                .tabItem { Label("Developer", systemImage: "hammer.fill") }
            
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 550, height: 450)
    }
}

// MARK: - General Tab
struct GeneralSettingsView: View {
    @Binding var appTheme: String
    @Binding var selectedVoiceID: String
    @Binding var selectedFont: String
    
    var voices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
    }
    
    let serifFonts = ["System", "Bodoni Moda", "Bodoni Moda SC", "Old Standard TT"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("General Settings").font(.title2).bold()
                Divider()
                
                // Theme
                VStack(alignment: .leading) {
                    Label("Appearance", systemImage: "paintbrush.fill").font(.headline)
                    Picker("", selection: $appTheme) {
                        Text("System").tag("System")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider()
                
                // Typography (Font Selector)
                VStack(alignment: .leading, spacing: 10) {
                    Label("Typography", systemImage: "textformat").font(.headline)
                    Picker("Serif Font", selection: $selectedFont) {
                        ForEach(serifFonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }
                    
                    if selectedFont != "System" {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Note: Ensure '\(selectedFont)' is installed in Font Book.")
                                .font(.caption).foregroundStyle(.secondary)
                            Link("Download from Google Fonts", destination: URL(string: "https://fonts.google.com/?query=\(selectedFont.replacingOccurrences(of: " ", with: "+"))")!)
                                .font(.caption)
                        }
                    }
                }
                
                Divider()
                
                // TTS
                VStack(alignment: .leading, spacing: 10) {
                    Label("Pronunciation Voice", systemImage: "waveform").font(.headline)
                    Picker("", selection: $selectedVoiceID) {
                        Text("System Default").tag("")
                        Divider()
                        ForEach(voices, id: \.identifier) { voice in
                            Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                        }
                    }
                }
            }
            .padding(30)
        }
    }
}

// MARK: - Developer Tab
struct DeveloperSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.gray.opacity(0.3))
                    
                    Text("Jack Davenport")
                        .font(.title).bold()
                    
                    Text("Student Developer, Conlanger, & Micronation Owner")
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Projects", systemImage: "folder.fill").font(.headline)
                        Text("• ConDict (macOS Dictionary Manager)")
                        Text("• The United Provinces of Sangaia (Micronation)")
                        Text("• Sangaian (Conlang)")
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Experience", systemImage: "graduationcap.fill").font(.headline)
                        Text("• SwiftUI & SwiftData Development")
                        Text("• macOS App Architecture")
                        Text("• High School Student")
                        Text("• HTML & CSS Coding")
                        Text("• Linux System Development")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(30)
        }
    }
}

// MARK: - About Tab
struct AboutSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image("AppIconSettings")
                    .resizable().scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(radius: 5)
                    .padding(.top, 20)
                
                VStack(spacing: 5) {
                    Text("ConDict").font(.largeTitle).bold().fontDesign(.serif)
                    Text("Alpha 1.2").foregroundStyle(.secondary)
                }
                
                Divider().padding(.vertical, 10)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("What's New in 1.2").font(.headline)
                    FeatureRow(icon: "map.fill", text: "Locations", subtext: "Track regional variations and dialects.")
                    FeatureRow(icon: "textformat.size", text: "Typography", subtext: "Customize the app with classic Serif fonts.")
                    FeatureRow(icon: "hammer.fill", text: "Developer", subtext: "Meet the creator behind ConDict.")
                    FeatureRow(icon: "folder.fill", text: "Improved Folders", subtext: "Colored icons and grid layout.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding()
        }
    }
}

// UPDATED: Now uses accent color dynamically
struct FeatureRow: View {
    let icon: String, text: String, subtext: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor) // Matches user system choice
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(text).fontWeight(.semibold)
                Text(subtext).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
