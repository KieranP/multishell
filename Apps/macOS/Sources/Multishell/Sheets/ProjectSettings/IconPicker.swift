import MultishellAppCore
import MultishellCore
import SwiftUI

/// The curated symbols as a palette: a button showing what is drawn now,
/// opening a grid under a heading per group. Names in one popup menu were
/// read line by line, which held the list to sixty; a grid is read by
/// shape, so it carries hundreds, with a field to narrow it by name and a
/// row of jumps along the foot. The folder is the first cell and clears the
/// glyph.
///
/// The menu it replaced could be driven from the keyboard, so this can too:
/// the field takes what is typed, Tab or Down moves into the grid, the
/// arrows walk it and Return picks.
struct IconPicker: View {
  let kind: ProjectIcon.Kind
  let tint: Color
  let choose: (String?) -> Void

  private enum Field: Hashable {
    case search
    case grid
  }

  @State private var isPresented = false
  @State private var query = ""
  @State private var highlighted: String?
  @FocusState private var focus: Field?

  private static let columns = 10
  private static let cellSize: Double = 26

  var body: some View {
    Button {
      query = ""
      highlighted = chosen
      isPresented = true
    } label: {
      field
    }
    .popover(isPresented: $isPresented, arrowEdge: .bottom) { palette }
  }

  private var field: some View {
    HStack(spacing: 6) {
      switch kind {
      case .folder:
        Image(systemName: "folder").foregroundStyle(tint)
        Text("Folder")
      case .symbol(let name):
        Image(systemName: name).foregroundStyle(tint)
        Text(name).lineLimit(1).truncationMode(.middle)
      }
      Spacer(minLength: 4)
      Image(systemName: "chevron.up.chevron.down")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    .frame(width: 190)
  }

  private var palette: some View {
    let groups = ProjectIcon.symbolGroups(matching: query)
    return ScrollViewReader { proxy in
      VStack(spacing: 6) {
        search(groups, proxy: proxy)
        if groups.isEmpty {
          Spacer()
          Text("No symbol called that").font(.system(size: 11)).foregroundStyle(.secondary)
          Spacer()
        } else {
          grid(groups, proxy: proxy)
          if query.isEmpty { jumps(groups, proxy: proxy) }
        }
      }
      .onAppear {
        highlighted = chosen
        // A frame later: the grid is lazy, and neither the cell to scroll
        // to nor the field to focus exists while the first pass is still
        // being laid out.
        Task {
          focus = .search
          proxy.scrollTo(chosen, anchor: .center)
        }
      }
    }
    .frame(width: Double(Self.columns) * (Self.cellSize + 2) + 22, height: 360)
  }

  private func search(_ groups: [ProjectIcon.Group], proxy: ScrollViewProxy) -> some View {
    HStack(spacing: 4) {
      Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
      TextField("Search", text: $query)
        .textFieldStyle(.plain)
        .focused($focus, equals: .search)
        .onKeyPress(.escape) {
          // A search field's Escape clears the search. Only once there is
          // nothing left to clear does it reach the popover and close it.
          guard !query.isEmpty else { return .ignored }
          query = ""
          return .handled
        }
        .onKeyPress(.downArrow) {
          focus = .grid
          // Whatever is about to take the ring is usually off screen, so
          // moving into the grid looks like nothing happening.
          if let highlighted { proxy.scrollTo(highlighted, anchor: .center) }
          return .handled
        }
        .onKeyPress(.return) { pickHighlighted() }
      if !query.isEmpty {
        Button {
          query = ""
          focus = .search
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Clear")
        .accessibilityLabel("Clear the search")
      }
    }
    .font(.system(size: 11))
    .padding(.horizontal, 8)
    .padding(.top, 8)
    .onChange(of: query) {
      // Nothing matched: drop the ring, or Return picks a symbol the filter
      // has taken off the screen.
      guard let first = groups.first else {
        highlighted = nil
        return
      }
      // A cleared search goes back to what the project is set to, not to the
      // top of the palette, which is where it was before the search.
      if query.isEmpty {
        highlighted = chosen
        proxy.scrollTo(chosen, anchor: .center)
      } else {
        highlighted = first.glyphs.first
        proxy.scrollTo(Self.headerID(first.name), anchor: .top)
      }
    }
  }

  private func grid(_ groups: [ProjectIcon.Group], proxy: ScrollViewProxy) -> some View {
    ScrollView {
      LazyVGrid(
        columns: Array(
          repeating: GridItem(.fixed(Self.cellSize), spacing: 2), count: Self.columns),
        spacing: 2,
        pinnedViews: [.sectionHeaders]
      ) {
        ForEach(groups, id: \.name) { group in
          Section {
            ForEach(group.glyphs, id: \.self) { cell($0) }
          } header: {
            header(group.name).id(Self.headerID(group.name))
          }
        }
      }
      .padding(.horizontal, 8)
      .padding(.bottom, 8)
    }
    .focusable()
    .focusEffectDisabled()
    .focused($focus, equals: .grid)
    .onKeyPress(.leftArrow) { walk(.left, through: groups, proxy: proxy) }
    .onKeyPress(.rightArrow) { walk(.right, through: groups, proxy: proxy) }
    .onKeyPress(.upArrow) { walk(.up, through: groups, proxy: proxy) }
    .onKeyPress(.downArrow) { walk(.down, through: groups, proxy: proxy) }
    .onKeyPress(.return) { pickHighlighted() }
  }

  /// One button per group, its first symbol standing for it, as the emoji
  /// picker's categories do. Fifty rows of scrolling is otherwise the only
  /// way from Files to Symbols.
  private func jumps(_ groups: [ProjectIcon.Group], proxy: ScrollViewProxy) -> some View {
    VStack(spacing: 0) {
      Divider()
      HStack(spacing: 0) {
        ForEach(groups, id: \.name) { group in
          Button {
            proxy.scrollTo(Self.headerID(group.name), anchor: .top)
          } label: {
            Image(systemName: group.glyphs.first ?? "square")
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              // Shared width, not a fixed one: a fifteenth group would
              // otherwise run off the edge of the popover unnoticed.
              .frame(maxWidth: .infinity, minHeight: 20)
              .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .help(group.name)
          .accessibilityLabel(group.name)
        }
      }
      .padding(.horizontal, 8)
      .padding(.top, 4)
      .padding(.bottom, 6)
    }
  }

  private static func headerID(_ group: String) -> String { "header." + group }

  private func header(_ name: String) -> some View {
    Text(name)
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 3)
      .background(.regularMaterial)
  }

  private func cell(_ name: String) -> some View {
    let selected = chosen == name
    return Button {
      pick(name)
    } label: {
      Image(systemName: name)
        .font(.system(size: 14))
        .foregroundStyle(selected ? Color.white : Color.primary)
        .frame(width: Self.cellSize, height: Self.cellSize)
        .background(selected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5))
        .overlay {
          if highlighted == name && focus == .grid {
            RoundedRectangle(cornerRadius: 5).strokeBorder(Color.accentColor, lineWidth: 2)
          }
        }
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(name)
    .accessibilityLabel(name)
  }

  /// Return picks what the ring is on, and is left alone when there is no
  /// ring, rather than swallowed.
  private func pickHighlighted() -> KeyPress.Result {
    guard let highlighted else { return .ignored }
    pick(highlighted)
    return .handled
  }

  private func pick(_ name: String) {
    choose(name == "folder" ? nil : name)
    isPresented = false
  }

  private func walk(
    _ step: IconGridWalk.Step, through groups: [ProjectIcon.Group], proxy: ScrollViewProxy
  ) -> KeyPress.Result {
    let rows = IconGridWalk.rows(of: groups, columns: Self.columns)
    guard let to = IconGridWalk.destination(from: highlighted, step: step, in: rows) else {
      return .ignored
    }
    return move(to: to, proxy: proxy)
  }

  private func move(to name: String, proxy: ScrollViewProxy) -> KeyPress.Result {
    highlighted = name
    proxy.scrollTo(name, anchor: .center)
    return .handled
  }

  private var chosen: String {
    switch kind {
    case .folder: "folder"
    case .symbol(let name): name
    }
  }
}
