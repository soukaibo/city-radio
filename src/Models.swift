import Foundation
import AVFoundation

struct Station: Codable, Identifiable, Hashable {
    let name: String
    let province: String
    let city: String
    let url: String
    let tags: String
    let codec: String
    let bitrate: Int
    let votes: Int
    let favicon: String
    let hls: Bool

    var id: String { url + "|" + name }
}

extension Station {
    var groupName: String {
        if province == "其他" {
            let n = name.uppercased()
            if n.contains("CNR") || n.contains("CRI") || n.contains("CCTV")
                || name.contains("中央") || name.contains("中国之声")
                || name.contains("环球") || name.contains("国际广播")
                || name.contains("经济之声") || name.contains("音乐之声")
                || name.contains("中华之声") || name.contains("神州") {
                return "中央台"
            }
            return "网络电台"
        }
        return province
    }

    var tagCN: String {
        let map: [String: String] = [
            "music": "音乐", "news": "新闻", "talk": "谈话", "traffic": "交通",
            "traffic radio broadcast": "交通", "traffic information": "交通",
            "entertainment": "娱乐", "information": "资讯", "oldies": "怀旧",
            "public radio": "公共", "lifestyle": "生活", "pop": "流行",
            "culture": "文化", "economics": "财经", "agriculture": "农业",
            "literature": "文艺", "storytelling": "评书", "tv": "电视伴音",
            "full service": "综合", "sports": "体育", "education": "教育",
            "variety": "综艺", "chinese": "中文", "comedy": "相声",
        ]
        var out: [String] = []
        for t in tags.split(separator: ",") {
            let key = t.trimmingCharacters(in: .whitespaces).lowercased()
            if let v = map[key], !out.contains(v) { out.append(v) }
        }
        return out.prefix(2).joined(separator: "·")
    }

    var subtitle: String {
        var parts: [String] = [groupName]
        if !city.isEmpty { parts.append(city) }
        if !tagCN.isEmpty { parts.append(tagCN) }
        if !codec.isEmpty && codec != "UNKNOWN" {
            parts.append(codec + (bitrate > 0 ? " \(bitrate)k" : ""))
        }
        return parts.joined(separator: " · ")
    }
}

final class StationStore {
    private(set) var all: [Station] = []
    private(set) var favorites: Set<String> = []
    private(set) var recent: [String] = []
    private let favKey = "cnradio.favorites"
    private let recentKey = "cnradio.recent"
    private let lastKey = "cnradio.lastStation"

    init() {
        load()
        favorites = Set(UserDefaults.standard.stringArray(forKey: favKey) ?? [])
        recent = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
    }

    private func load() {
        guard let u = Bundle.main.url(forResource: "stations", withExtension: "json"),
              let d = try? Data(contentsOf: u),
              let arr = try? JSONDecoder().decode([Station].self, from: d) else {
            all = []
            return
        }
        all = arr
    }

    var groups: [String] {
        let priority = ["中央台", "北京", "上海", "天津", "重庆", "广东", "浙江", "江苏",
                        "山东", "河南", "河北", "四川", "湖北", "湖南", "辽宁", "吉林",
                        "黑龙江", "安徽", "福建", "江西", "山西", "陕西", "甘肃", "云南",
                        "贵州", "广西", "海南", "内蒙古", "新疆", "宁夏", "青海", "西藏",
                        "香港", "澳门", "台湾", "网络电台"]
        var counts: [String: Int] = [:]
        for s in all { counts[s.groupName, default: 0] += 1 }
        var ordered: [String] = []
        for p in priority where counts[p] != nil { ordered.append(p) }
        for p in counts.keys.sorted() where !ordered.contains(p) { ordered.append(p) }
        return ordered
    }

    func count(in group: String) -> Int {
        all.reduce(0) { $0 + ($1.groupName == group ? 1 : 0) }
    }

    func stations(in group: String) -> [Station] {
        all.filter { $0.groupName == group }.sorted { $0.votes > $1.votes }
    }

    func toggleFavorite(_ s: Station) {
        if favorites.contains(s.id) { favorites.remove(s.id) } else { favorites.insert(s.id) }
        UserDefaults.standard.set(Array(favorites), forKey: favKey)
    }

    func isFavorite(_ s: Station) -> Bool { favorites.contains(s.id) }
    func station(byURL url: String) -> Station? { all.first { $0.id == url } }

    var favoriteStations: [Station] { favorites.compactMap { station(byURL: $0) } }
    var recentStations: [Station] { recent.compactMap { station(byURL: $0) } }

    func markRecent(_ s: Station) {
        var r = recent.filter { $0 != s.id }
        r.insert(s.id, at: 0)
        if r.count > 30 { r = Array(r.prefix(30)) }
        recent = r
        UserDefaults.standard.set(r, forKey: recentKey)
    }

    /// 记录"最后播放的电台"，供下次启动自动续播
    func saveLast(_ s: Station) {
        UserDefaults.standard.set(s.id, forKey: lastKey)
    }

    var lastStation: Station? {
        guard let id = UserDefaults.standard.string(forKey: lastKey) else { return nil }
        return station(byURL: id)
    }
}

final class PlayerEngine: NSObject {
    private let player = AVPlayer()
    private(set) var current: Station?
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var errorText = ""
    var onChange: (() -> Void)?

    var volume: Double = 0.7 {
        didSet { player.volume = Float(volume) }
    }

    override init() {
        super.init()
        player.volume = Float(volume)
        player.automaticallyWaitsToMinimizeStalling = true
        player.addObserver(self, forKeyPath: "timeControlStatus", options: [.new], context: nil)
    }

    deinit {
        player.removeObserver(self, forKeyPath: "timeControlStatus")
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard keyPath == "timeControlStatus" else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isBuffering = (self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate)
            self.isPlaying = (self.player.timeControlStatus == .playing)
            self.onChange?()
        }
    }

    func play(_ s: Station) {
        guard let u = URL(string: s.url) else {
            errorText = "地址无效"
            onChange?()
            return
        }
        errorText = ""
        current = s
        let item = AVPlayerItem(url: u)
        item.preferredForwardBufferDuration = 2
        NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.errorText = "这个流暂时连不上，换一个试试"
            self.isPlaying = false
            self.isBuffering = false
            self.onChange?()
        }
        player.replaceCurrentItem(with: item)
        player.play()
        isBuffering = true
        onChange?()
    }

    func toggle() {
        guard current != nil else { return }
        if isPlaying || isBuffering {
            player.pause()
            isPlaying = false
            isBuffering = false
        } else {
            player.play()
            isBuffering = true
        }
        onChange?()
    }

    func resume() {
        guard current != nil else { return }
        player.play()
        isBuffering = true
        onChange?()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        current = nil
        isPlaying = false
        isBuffering = false
        errorText = ""
        onChange?()
    }
}
