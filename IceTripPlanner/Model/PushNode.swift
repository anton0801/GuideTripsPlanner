import Foundation

class PushNode: NSObject {
    func ingest(_ payload: [AnyHashable: Any]) {
        guard let url = extract(from: payload) else { return }
        UserDefaults.standard.set(url, forKey: "temp_url")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            NotificationCenter.default.post(name: .init("LoadTempURL"), object: nil, userInfo: ["temp_url": url])
        }
    }

    private func extract(from p: [AnyHashable: Any]) -> String? {
        if let u = p["url"]    as? String { return u }
        if let d = p["data"]   as? [String: Any], let u = d["url"]        as? String { return u }
        if let a = p["aps"]    as? [String: Any], let d = a["data"] as? [String: Any], let u = d["url"] as? String { return u }
        if let c = p["custom"] as? [String: Any], let u = c["url"] as? String { return u }
        return nil
    }
}
