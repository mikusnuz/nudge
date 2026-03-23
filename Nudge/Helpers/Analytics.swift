import Foundation

enum Analytics {
    private static let apiURL = "https://analytics.plumbug.studio/api/track"
    private static let clientId = "efe540d4-26a3-47a3-a816-bdc93b0ccd56"

    static func track(_ name: String, properties: [String: String] = [:]) {
        var body: [String: Any] = [
            "type": "track",
            "payload": [
                "name": name,
                "properties": properties
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(clientId, forHTTPHeaderField: "openpanel-client-id")
        request.httpBody = data

        URLSession.shared.dataTask(with: request).resume()
    }
}
