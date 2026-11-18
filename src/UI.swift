import Cocoa

enum SidebarSel: Hashable {
    case all
    case favorites
    case recent
    case group(String)
}

struct SidebarItem {
    let title: String
    let sel: SidebarSel
    let count: Int
}

final class SidebarCell: NSTableCellView {
    let titleLabel = NSTextField(labelWithString: "")
    let countLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        titleLabel.font = NSFont.systemFont(ofSize: 12)
        titleLabel.lineBreakMode = .byTruncatingTail
        countLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .right
        addSubview(titleLabel)
        addSubview(countLabel)
        textField = titleLabel
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let h = bounds.height
        countLabel.frame = NSRect(x: bounds.width - 44, y: (h - 14) / 2, width: 36, height: 14)
        titleLabel.frame = NSRect(x: 12, y: (h - 17) / 2, width: max(10, bounds.width - 62), height: 17)
    }

    func configure(title: String, count: Int) {
        titleLabel.stringValue = title
        countLabel.stringValue = "\(count)"
        needsLayout = true
    }
}

final class StationCell: NSTableCellView {
    let titleLabel = NSTextField(labelWithString: "")
    let subLabel = NSTextField(labelWithString: "")
    let starButton = NSButton()
    let waveImage = NSImageView()
    var onStar: (() -> Void)?
    var station: Station?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        titleLabel.font = NSFont.systemFont(ofSize: 13)
        titleLabel.lineBreakMode = .byTruncatingTail
        subLabel.font = NSFont.systemFont(ofSize: 10)
        subLabel.textColor = .secondaryLabelColor
        subLabel.lineBreakMode = .byTruncatingTail

        starButton.isBordered = false
        starButton.imagePosition = .imageOnly
        starButton.target = self
        starButton.action = #selector(starClicked)

        waveImage.imageScaling = .scaleProportionallyDown

        [waveImage, titleLabel, subLabel, starButton].forEach { addSubview($0) }
        textField = titleLabel
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let h = bounds.height
        let w = bounds.width
        waveImage.frame = NSRect(x: 4, y: (h - 14) / 2, width: 14, height: 14)
        starButton.frame = NSRect(x: w - 26, y: (h - 18) / 2, width: 18, height: 18)
        let textW = max(20, w - 4 - 14 - 8 - 26 - 6)
        titleLabel.frame = NSRect(x: 26, y: h - 4 - 17, width: textW, height: 17)
        subLabel.frame = NSRect(x: 26, y: h - 4 - 17 - 14, width: textW, height: 14)
    }

    @objc private func starClicked() {
        onStar?()
    }

    func configure(_ s: Station, isCurrent: Bool, playing: Bool, fav: Bool) {
        station = s
        titleLabel.stringValue = s.name
        subLabel.stringValue = s.subtitle
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: isCurrent ? .semibold : .regular)
        let symbol = isCurrent ? (playing ? "waveform" : "pause.circle.fill") : "dot.radiowaves.left.and.right"
        waveImage.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        waveImage.contentTintColor = isCurrent ? .controlAccentColor : .tertiaryLabelColor
        starButton.image = NSImage(systemSymbolName: fav ? "star.fill" : "star", accessibilityDescription: "收藏")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .regular))
        starButton.contentTintColor = fav ? .systemYellow : .tertiaryLabelColor
        needsLayout = true
    }
}

final class MainViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    let store: StationStore
    let player: PlayerEngine

    private let sideTable = NSTableView()
    private let listTable = NSTableView()
    private let searchField = NSSearchField()
    private let countLabel = NSTextField(labelWithString: "")
    private let playButton = NSButton()
    private let favButton = NSButton()
    private let stopButton = NSButton()
    private let volumeSlider = NSSlider()
    private let nowTitle = NSTextField(labelWithString: "未选择电台")
    private let nowSub = NSTextField(labelWithString: "点任意电台即可开始收听")
    private let coverIcon = NSImageView()
    private let coverBG = NSView()

    private var sideItems: [SidebarItem] = []
    private var selection: SidebarSel = .all
    private var rows: [Station] = []
    private let sideScroll = NSScrollView()
    private let listScroll = NSScrollView()

    init(store: StationStore, player: PlayerEngine) {
        self.store = store
        self.player = player
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        root.autoresizesSubviews = true
        view = root

        // 顶部搜索栏
        let topBar = NSView(frame: NSRect(x: 0, y: 600 - 42, width: 900, height: 42))
        topBar.autoresizingMask = [.width, .minYMargin]
        root.addSubview(topBar)

        searchField.frame = NSRect(x: 12, y: 8, width: 340, height: 26)
        searchField.placeholderString = "搜索城市、电台名或类型（交通/音乐/评书…）"
        searchField.font = NSFont.systemFont(ofSize: 12)
        searchField.delegate = self
        topBar.addSubview(searchField)

        countLabel.frame = NSRect(x: 420, y: 13, width: 380, height: 16)
        countLabel.autoresizingMask = [.minXMargin]
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .right
        topBar.addSubview(countLabel)

        let divider1 = NSBox(frame: NSRect(x: 0, y: 557, width: 900, height: 1))
        divider1.boxType = .separator
        divider1.autoresizingMask = [.width, .minYMargin]
        root.addSubview(divider1)

        // 侧栏
        setupSideTable()
        sideScroll.frame = NSRect(x: 0, y: 61, width: 186, height: 600 - 42 - 1 - 60 - 1)
        sideScroll.autoresizingMask = [.height]
        sideScroll.documentView = sideTable
        sideScroll.hasVerticalScroller = true
        sideScroll.autohidesScrollers = true
        sideScroll.drawsBackground = true
        sideScroll.backgroundColor = NSColor.underPageBackgroundColor
        root.addSubview(sideScroll)

        let divider2 = NSBox(frame: NSRect(x: 186, y: 61, width: 1, height: 600 - 42 - 1 - 60 - 1))
        divider2.boxType = .separator
        divider2.autoresizingMask = [.height]
        root.addSubview(divider2)

        // 电台列表
        setupListTable()
        listScroll.frame = NSRect(x: 187, y: 61, width: 713, height: 600 - 42 - 1 - 60 - 1)
        listScroll.autoresizingMask = [.width, .height]
        listScroll.documentView = listTable
        listScroll.hasVerticalScroller = true
        listScroll.autohidesScrollers = true
        root.addSubview(listScroll)

        let divider3 = NSBox(frame: NSRect(x: 0, y: 60, width: 900, height: 1))
        divider3.boxType = .separator
        divider3.autoresizingMask = [.width, .maxYMargin]
        root.addSubview(divider3)

        // 底部播放条
        let bar = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 60))
        bar.autoresizingMask = [.width, .maxYMargin]
        root.addSubview(bar)
        buildPlayerBar(in: bar)

        reloadSidebar()
        selectSidebar(row: 0)
        updatePlayerUI()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        listTable.sizeLastColumnToFit()
        sideTable.sizeLastColumnToFit()
    }

    private func setupSideTable() {
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("side"))
        col.width = 186
        sideTable.addTableColumn(col)
        sideTable.headerView = nil
        sideTable.rowHeight = 26
        sideTable.backgroundColor = .underPageBackgroundColor
        if #available(macOS 11.0, *) { sideTable.style = .sourceList }
        sideTable.allowsEmptySelection = false
        sideTable.dataSource = self
        sideTable.delegate = self
        sideTable.frame = NSRect(x: 0, y: 0, width: 186, height: 400)
    }

    private func setupListTable() {
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("station"))
        col.width = 700
        col.resizingMask = .autoresizingMask
        listTable.addTableColumn(col)
        listTable.headerView = nil
        listTable.rowHeight = 42
        listTable.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        listTable.dataSource = self
        listTable.delegate = self
        listTable.target = self
        listTable.action = #selector(listRowClicked)
    }

    private func buildPlayerBar(in bar: NSView) {
        coverBG.frame = NSRect(x: 12, y: 10, width: 40, height: 40)
        coverBG.autoresizingMask = [.maxXMargin]
        coverBG.wantsLayer = true
        coverBG.layer?.cornerRadius = 7
        coverBG.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor
        bar.addSubview(coverBG)

        coverIcon.frame = NSRect(x: 21, y: 19, width: 22, height: 22)
        coverIcon.autoresizingMask = [.maxXMargin]
        coverIcon.imageScaling = .scaleProportionallyUpOrDown
        coverIcon.image = NSImage(systemSymbolName: "radio.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 18, weight: .regular))
        coverIcon.contentTintColor = .controlAccentColor
        bar.addSubview(coverIcon)

        nowTitle.frame = NSRect(x: 64, y: 32, width: 330, height: 17)
        nowTitle.autoresizingMask = [.maxXMargin]
        nowTitle.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nowTitle.lineBreakMode = .byTruncatingTail
        bar.addSubview(nowTitle)

        nowSub.frame = NSRect(x: 64, y: 16, width: 330, height: 14)
        nowSub.autoresizingMask = [.maxXMargin]
        nowSub.font = NSFont.systemFont(ofSize: 10)
        nowSub.textColor = .secondaryLabelColor
        nowSub.lineBreakMode = .byTruncatingTail
        bar.addSubview(nowSub)

        configureIconButton(playButton, symbol: "play.fill", size: 15, action: #selector(playPause))
        playButton.frame = NSRect(x: 654, y: 15, width: 34, height: 30)
        playButton.autoresizingMask = [.minXMargin]
        bar.addSubview(playButton)

        configureIconButton(favButton, symbol: "star", size: 13, action: #selector(toggleFav))
        favButton.frame = NSRect(x: 694, y: 17, width: 26, height: 26)
        favButton.autoresizingMask = [.minXMargin]
        bar.addSubview(favButton)

        let volIcon = NSImageView(frame: NSRect(x: 736, y: 24, width: 14, height: 13))
        volIcon.autoresizingMask = [.minXMargin]
        volIcon.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .regular))
        volIcon.contentTintColor = .secondaryLabelColor
        bar.addSubview(volIcon)

        volumeSlider.frame = NSRect(x: 756, y: 21, width: 92, height: 19)
        volumeSlider.autoresizingMask = [.minXMargin]
        volumeSlider.minValue = 0
        volumeSlider.maxValue = 1
        volumeSlider.doubleValue = player.volume
        volumeSlider.target = self
        volumeSlider.action = #selector(volumeChanged)
        volumeSlider.controlSize = .small
        bar.addSubview(volumeSlider)

        configureIconButton(stopButton, symbol: "stop.fill", size: 11, action: #selector(stopPlay))
        stopButton.frame = NSRect(x: 862, y: 17, width: 26, height: 26)
        stopButton.autoresizingMask = [.minXMargin]
        bar.addSubview(stopButton)
    }

    private func configureIconButton(_ b: NSButton, symbol: String, size: CGFloat, action: Selector) {
        b.isBordered = false
        b.bezelStyle = .regularSquare
        b.imagePosition = .imageOnly
        b.target = self
        b.action = action
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size, weight: .medium))
        b.contentTintColor = .labelColor
    }

    // MARK: - 数据

    private func reloadSidebar() {
        sideItems = [
            SidebarItem(title: "全部电台", sel: .all, count: store.all.count),
            SidebarItem(title: "收藏", sel: .favorites, count: store.favorites.count),
            SidebarItem(title: "最近播放", sel: .recent, count: store.recent.count),
        ]
        for g in store.groups {
            sideItems.append(SidebarItem(title: g, sel: .group(g), count: store.count(in: g)))
        }
        sideTable.reloadData()
    }

    private func selectSidebar(row: Int) {
        guard row >= 0 && row < sideItems.count else { return }
        selection = sideItems[row].sel
        sideTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        reloadList()
    }

    private func reloadList() {
        let q = searchField.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
        var base: [Station]
        switch selection {
        case .all: base = store.all.sorted { $0.votes > $1.votes }
        case .favorites: base = store.favoriteStations
        case .recent: base = store.recentStations
        case .group(let g): base = store.stations(in: g)
        }
        if !q.isEmpty {
            base = base.filter {
                $0.name.lowercased().contains(q)
                    || $0.groupName.lowercased().contains(q)
                    || $0.city.lowercased().contains(q)
                    || $0.tags.lowercased().contains(q)
                    || $0.tagCN.contains(q)
            }
        }
        rows = base
        countLabel.stringValue = "\(rows.count) 个电台"
        listTable.reloadData()
    }

    // MARK: - 表格

    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === sideTable ? sideItems.count : rows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === sideTable {
            let id = NSUserInterfaceItemIdentifier("sb")
            var cell = tableView.makeView(withIdentifier: id, owner: nil) as? SidebarCell
            if cell == nil {
                cell = SidebarCell(frame: NSRect(x: 0, y: 0, width: 186, height: 26))
                cell?.identifier = id
            }
            let item = sideItems[row]
            cell?.configure(title: item.title, count: item.count)
            return cell
        } else {
            let id = NSUserInterfaceItemIdentifier("st")
            var cell = tableView.makeView(withIdentifier: id, owner: nil) as? StationCell
            if cell == nil {
                cell = StationCell(frame: NSRect(x: 0, y: 0, width: 700, height: 42))
                cell?.identifier = id
            }
            let s = rows[row]
            let isCurrent = (player.current?.id == s.id)
            cell?.configure(s, isCurrent: isCurrent, playing: player.isPlaying, fav: store.isFavorite(s))
            cell?.onStar = { [weak self] in
                guard let self = self else { return }
                self.store.toggleFavorite(s)
                self.reloadSidebar()
                self.listTable.reloadData()
                self.updatePlayerUI()
            }
            return cell
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTableView, tv === sideTable else { return }
        let r = sideTable.selectedRow
        guard r >= 0 && r < sideItems.count else { return }
        selection = sideItems[r].sel
        reloadList()
    }

    @objc private func listRowClicked() {
        let r = listTable.clickedRow
        guard r >= 0 && r < rows.count else { return }
        let s = rows[r]
        player.play(s)
        store.markRecent(s)
        store.saveLast(s)
        listTable.reloadData()
        updatePlayerUI()
    }

    /// 启动时自动续播上次关闭前的电台
    func autoResumeLast() {
        guard let s = store.lastStation else { return }
        player.play(s)
        store.markRecent(s)
        listTable.reloadData()
        updatePlayerUI()
    }

    // MARK: - 播放控制

    @objc func playPause() {
        player.toggle()
        listTable.reloadData()
        updatePlayerUI()
    }

    @objc func stopPlay() {
        player.stop()
        listTable.reloadData()
        updatePlayerUI()
    }

    @objc private func toggleFav() {
        guard let cur = player.current else { return }
        store.toggleFavorite(cur)
        reloadSidebar()
        listTable.reloadData()
        updatePlayerUI()
    }

    @objc private func volumeChanged() {
        player.volume = volumeSlider.doubleValue
    }

    func controlTextDidChange(_ obj: Notification) {
        reloadList()
    }

    func updatePlayerUI() {
        if let s = player.current {
            nowTitle.stringValue = s.name
            var parts: [String] = [s.groupName]
            if !s.city.isEmpty { parts.append(s.city) }
            if !s.tagCN.isEmpty { parts.append(s.tagCN) }
            let state = player.isBuffering ? "连接中…" : (player.isPlaying ? "正在播放" : "已暂停")
            parts.insert(state, at: 0)
            nowSub.stringValue = player.errorText.isEmpty ? parts.joined(separator: " · ") : player.errorText
            nowSub.textColor = player.errorText.isEmpty ? .secondaryLabelColor : .systemRed
            favButton.isEnabled = true
            let fav = store.isFavorite(s)
            favButton.image = NSImage(systemSymbolName: fav ? "star.fill" : "star", accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
            favButton.contentTintColor = fav ? .systemYellow : .labelColor
        } else {
            nowTitle.stringValue = "未选择电台"
            nowSub.stringValue = "点任意电台即可开始收听"
            nowSub.textColor = .secondaryLabelColor
            favButton.isEnabled = false
        }
        let playing = player.isPlaying || player.isBuffering
        playButton.image = NSImage(systemSymbolName: playing ? "pause.fill" : "play.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .medium))
        playButton.isEnabled = player.current != nil
        stopButton.isEnabled = player.current != nil
        coverIcon.contentTintColor = player.isPlaying ? .controlAccentColor : .secondaryLabelColor
    }

    /// 供状态栏/菜单触发，按名称直接播放
    func playStation(named keyword: String) {
        if let s = store.all.first(where: { $0.name.contains(keyword) }) {
            player.play(s)
            store.markRecent(s)
            store.saveLast(s)
            listTable.reloadData()
            updatePlayerUI()
        }
    }
}
