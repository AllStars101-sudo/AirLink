import Foundation
import UIKit

class GeminiService {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"
    
    init() {
        self.apiKey = APIKeyManager.shared.geminiAPIKey
        
        // Debug logging
        print("🔑 Gemini Service Initialized:")
        print("  - Key present: \(!apiKey.isEmpty)")
        if !apiKey.isEmpty {
            print("  - Key length: \(apiKey.count)")
            print("  - Key preview: \(String(apiKey.prefix(8)))...")
        }
    }
    
    func analyzeScene(image: UIImage) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AIError.apiError("Failed to convert image to data")
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let request = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(text: """
                        Analyze this scene for photography composition. Consider:
                        1. Subject positioning and rule of thirds
                        2. Lighting conditions and optimal exposure
                        3. Background elements and depth of field
                        4. Potential camera movements for dynamic shots
                        5. Best gimbal positioning for this scene
                        
                        Provide specific recommendations for AirFrame gimbal positioning (pitch, yaw, roll adjustments) to capture the best possible shot. Be concise but detailed about the optimal framing and camera settings.
                        """),
                        GeminiPart(
                            inlineData: GeminiInlineData(
                                mimeType: "image/jpeg",
                                data: base64Image
                            )
                        )
                    ]
                )
            ]
        )
        
        let jsonData = try JSONEncoder().encode(request)
        
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)?key=\(apiKey)")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = jsonData
        
        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.apiError("Invalid response type")
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.apiError("Gemini API Error: \(message)")
            }
            throw AIError.apiError("HTTP Error: \(httpResponse.statusCode)")
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: responseData)
        
        guard let firstCandidate = geminiResponse.candidates.first,
              let firstPart = firstCandidate.content.parts.first,
              let responseText = firstPart.text else {
            throw AIError.apiError("No response content from Gemini")
        }
        
        return responseText
    }
}

// MARK: - Gemini API Models
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String?
    let inlineData: GeminiInlineData?
    
    init(text: String) {
        self.text = text
        self.inlineData = nil
    }
    
    init(inlineData: GeminiInlineData) {
        self.text = nil
        self.inlineData = inlineData
    }
    
    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

struct GeminiInlineData: Codable {
    let mimeType: String
    let data: String
    
    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
    let finishReason: String?
    let index: Int?
    
    enum CodingKeys: String, CodingKey {
        case content, index
        case finishReason = "finishReason"
    }
}