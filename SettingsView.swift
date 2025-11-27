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
        .frame(width: 600, height: 500)
    }
}

// MARK: - General Tab
struct GeneralSettingsView: View {
    @Binding var appTheme: String
    @Binding var selectedVoiceID: String
    @Binding var selectedFont: String
    
    @State private var fontScriptFilter = "All"
    @State private var selectedLanguageFilter = "en"
    
    // --- Data Sources ---
    
    var availableLanguages: [String] {
        let codes = Set(AVSpeechSynthesisVoice.speechVoices().map { String($0.language.prefix(2)) })
        return codes.sorted()
    }
    
    var filteredVoices: [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: selectedLanguageFilter) }
        
        if selectedLanguageFilter == "en" {
            var results: [AVSpeechSynthesisVoice] = []
            if let us = allVoices.first(where: { $0.language == "en-US" }) { results.append(us) }
            if let gb = allVoices.first(where: { $0.language == "en-GB" }) { results.append(gb) }
            if let au = allVoices.first(where: { $0.language == "en-AU" }) { results.append(au) }
            return results.isEmpty ? Array(allVoices.prefix(3)) : results
        }
        return Array(allVoices.prefix(3))
    }
    
    // Script Categories
    let scripts = [
        "All", "Latin", "Arabic", "Armenian", "Balinese", "Bengali",
        "Cyrillic", "Devanagari", "Ethiopic", "Georgian", "Glagolitic",
        "Greek", "Hebrew", "Hiragana", "Korean"
    ]
    
    // Font Mapping
    var fontOptions: [String] {
        switch fontScriptFilter {
        case "All": return ["System"]
        case "Latin": return ["Bodoni Moda"]
        case "Arabic": return ["Ruwudu"]
        case "Armenian": return ["Noto Serif Armenian"]
        case "Balinese": return ["Noto Serif Balinese"]
        case "Bengali": return ["Tiro Bangla"]
        case "Cyrillic": return ["Ledger"]
        case "Devanagari": return ["Rozha One"]
        case "Ethiopic": return ["Abyssinica SL"]
        case "Georgian": return ["Noto Serif Georgian"]
        case "Glagolitic": return ["Shafarik"]
        case "Greek": return ["Noto Serif Display"]
        case "Hebrew": return ["Frank Ruhl Libre"]
        case "Hiragana": return ["Zen Old Mincho"]
        case "Korean": return ["Song Myung"]
        default: return ["System"]
        }
    }
    
    // --- Body ---
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                
                // Header
                Text("General Settings")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 10)
                
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
                
                // Typography
                VStack(alignment: .leading, spacing: 10) {
                    Label("Typography", systemImage: "textformat").font(.headline)
                    
                    HStack {
                        // Script Picker
                        Picker("Script", selection: $fontScriptFilter) {
                            ForEach(scripts, id: \.self) { script in
                                Text(script).tag(script)
                            }
                        }
                        .frame(width: 140)
                        .onChange(of: fontScriptFilter) { _, newValue in
                            // Auto-select the font when script changes
                            if newValue == "All" {
                                selectedFont = "System"
                            } else if let firstFont = fontOptions.first {
                                selectedFont = firstFont
                            }
                        }
                        
                        // Font Picker
                        Picker("Font", selection: $selectedFont) {
                            if fontScriptFilter == "All" {
                                Text("System").tag("System")
                            } else {
                                ForEach(fontOptions, id: \.self) { font in
                                    Text(font).tag(font)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    if selectedFont != "System" {
                        Link("Download font from Google Fonts", destination: URL(string: "https://fonts.google.com/?query=\(selectedFont.replacingOccurrences(of: " ", with: "+"))")!)
                            .font(.caption)
                    }
                }
                
                Divider()
                
                // TTS
                VStack(alignment: .leading, spacing: 10) {
                    Label("Pronunciation Voice", systemImage: "waveform").font(.headline)
                    
                    HStack {
                        Picker("Language", selection: $selectedLanguageFilter) {
                            ForEach(availableLanguages, id: \.self) { code in
                                Text(Locale.current.localizedString(forLanguageCode: code) ?? code).tag(code)
                            }
                        }
                        .frame(width: 150)
                        
                        Picker("Voice", selection: $selectedVoiceID) {
                            Text("System Default").tag("")
                            Divider()
                            ForEach(filteredVoices, id: \.identifier) { voice in
                                Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                            }
                        }
                    }
                }
            }
            .padding(40)
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
                    Text("Jack Davenport").font(.title).bold()
                    Text("Student Developer, Conlanger, & Micronation Owner").foregroundStyle(.secondary)
                }
                Divider()
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Projects", systemImage: "folder.fill").font(.headline)
                        Text("• ConDict (macOS Dictionary Manager)").foregroundStyle(.secondary)
                        Text("• The United Provinces of Sangaia").foregroundStyle(.secondary)
                        Text("• Sangaian (Conlang)").foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Experience", systemImage: "graduationcap.fill").font(.headline)
                        Text("• SwiftUI & SwiftData").foregroundStyle(.secondary)
                        Text("• macOS App Architecture").foregroundStyle(.secondary)
                        Text("• High School Student").foregroundStyle(.secondary)
                        Text("• HTML & CSS Coding").foregroundStyle(.secondary)
                        Text("• Linux System Development").foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(40)
        }
    }
}

// MARK: - About Tab
struct AboutSettingsView: View {
    @State private var showHistory = false
    
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
                    Text("Alpha 1.3").foregroundStyle(.secondary)
                }
                
                Divider().padding(.vertical, 10)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("What's New in 1.3").font(.headline)
                    FeatureRow(icon: "books.vertical.fill", text: "Libraries", subtext: "Create multiple separate dictionaries.")
                    FeatureRow(icon: "waveform.circle.fill", text: "Smart TTS", subtext: "Better voice selection & Chinese support.")
                    FeatureRow(icon: "textformat", text: "Scripts", subtext: "Filter fonts by script & 13 new scripts added.")
                    FeatureRow(icon: "mappin.and.ellipse", text: "Origins", subtext: "Location tags now match your accent color.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button("View Older Versions") { showHistory = true }
                    .buttonStyle(.link)
                    .padding()
            }
            .padding()
        }
        .sheet(isPresented: $showHistory) {
            VersionHistoryView()
        }
    }
}

struct VersionHistoryView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack {
            Text("Older Versions").font(.title2).bold().padding()
            List {
                Section("Alpha 1.2") {
                    Text("• Added font changing")
                    Text("• New Developer page in Settings")
                    Text("• Added location tags")
                    Text("• Added Cyrillic support")
                    Text("• Recolored some folders")
                    Text("• Images are now cropped to a certain size")
                    Text("• Adjusted fonts")
                    Text("• Updated the Whats New Page")
                }
                Section("Alpha 1.1") {
                    Text("• Added a translation grid")
                    Text("• Added a Settings page")
                    Text("• Added word libraries")
                    Text("• Added word folders")
                    Text("• Added markdown editing")
                    Text("• Added the ability to attach images to words")
                    Text("• Refined the Edit menu")
                    Text("• Added a Whats New page")
                }
                Section("Alpha 1.0") {
                    Text("• Initial release")
                    
                }
            }
            Button("Close") { dismiss() }.padding()
        }
        .frame(width: 400, height: 500)
    }
}

struct FeatureRow: View {
    let icon: String, text: String, subtext: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.accentColor).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(text).fontWeight(.semibold)
                Text(subtext).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
