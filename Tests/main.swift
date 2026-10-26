import Foundation

func assert(_ condition: Bool, _ message: String) {
    if !condition {
        print("❌ Test Failed: \(message)")
        exit(1)
    }
}

func testParseValidJSON() {
    print("Running testParseValidJSON...")

    let jsonString = """
        {
          "formulae": [
            {
              "name": "git",
              "installed_versions": ["2.39.0"],
              "current_version": "2.40.0",
              "pinned": false,
              "pinned_version": null,
              "homepage": "https://git-scm.com"
            }
          ],
          "casks": [
            {
              "name": "google-chrome",
              "installed_versions": ["110.0.5481.177"],
              "current_version": "111.0.5563.64",
              "homepage": "https://www.google.com/chrome/"
            }
          ]
        }
        """

    guard let data = jsonString.data(using: .utf8) else {
        print("❌ Failed to create data from string")
        exit(1)
    }

    do {
        let packages = try BrewService.parse(data: data)

        assert(packages.count == 2, "Expected 2 packages, got \(packages.count)")

        let git = packages.first { $0.name == "git" }
        assert(git != nil, "Git package not found")
        assert(git?.currentVersion == "2.39.0", "Git current version mismatch")
        assert(git?.availableVersion == "2.40.0", "Git available version mismatch")
        assert(git?.homepage == "https://git-scm.com", "Git homepage mismatch")

        let chrome = packages.first { $0.name == "google-chrome" }
        assert(chrome != nil, "Chrome package not found")
        assert(chrome?.currentVersion == "110.0.5481.177", "Chrome current version mismatch")
        assert(chrome?.homepage == "https://www.google.com/chrome/", "Chrome homepage mismatch")

        print("✅ testParseValidJSON Passed")
    } catch {
        print("❌ Unexpected error: \(error)")
        exit(1)
    }
}

func testParseEmptyJSON() {
    print("Running testParseEmptyJSON...")
    let jsonString = """
        {
          "formulae": [],
          "casks": []
        }
        """
    guard let data = jsonString.data(using: .utf8) else { return }

    do {
        let packages = try BrewService.parse(data: data)
        assert(packages.isEmpty, "Expected 0 packages, got \(packages.count)")
        print("✅ testParseEmptyJSON Passed")
    } catch {
        print("❌ Unexpected error: \(error)")
        exit(1)
    }
}

func testParseServices() {
    print("Running testParseServices...")
    let jsonString = """
        [
          {
            "name": "atuin",
            "status": "none",
            "user": null,
            "file": "/opt/homebrew/opt/atuin/homebrew.mxcl.atuin.plist",
            "exit_code": null
          },
          {
            "name": "colima",
            "status": "error",
            "user": "frankp",
            "file": "/Users/frankp/Library/LaunchAgents/homebrew.mxcl.colima.plist",
            "exit_code": 1
          },
          {
            "name": "nginx",
            "status": "started",
            "user": "root",
            "file": "/opt/homebrew/opt/nginx/homebrew.mxcl.nginx.plist",
            "exit_code": 0
          }
        ]
        """
    guard let data = jsonString.data(using: .utf8) else {
        print("❌ Failed to create data from string")
        exit(1)
    }

    do {
        let services = try BrewService.parseServices(data: data)
        assert(services.count == 3, "Expected 3 services, got \(services.count)")

        let atuin = services.first { $0.name == "atuin" }
        assert(atuin != nil, "Atuin service not found")
        assert(atuin?.status == "none", "Atuin status mismatch")
        assert(!(atuin?.isRunning ?? true), "Atuin should not be running")

        let colima = services.first { $0.name == "colima" }
        assert(colima != nil, "Colima service not found")
        assert(colima?.status == "error", "Colima status mismatch")
        assert(colima?.isError ?? false, "Colima should have error")

        let nginx = services.first { $0.name == "nginx" }
        assert(nginx != nil, "Nginx service not found")
        assert(nginx?.status == "started", "Nginx status mismatch")
        assert(nginx?.isRunning ?? false, "Nginx should be running")

        print("✅ testParseServices Passed")
    } catch {
        print("❌ Unexpected error: \(error)")
        exit(1)
    }
}

func testProgressStep() {
    print("Running testProgressStep...")
    let cases: [(String, String?)] = [
        ("==> Downloading https://ghcr.io/v2/homebrew/core/node/blobs/sha256:abc", "Downloading"),
        ("==> Pouring node--22.2.0.arm64_sequoia.bottle.tar.gz", "Pouring"),
        ("==> Upgrading node 22.1.0 -> 22.2.0", "Upgrading node 22.1.0 -> 22.2.0"),
        ("🍺  /opt/homebrew/Cellar/node/22.2.0: 2,000 files, 70MB", "Installed"),
        ("Error: node is pinned", "Error: node is pinned"),
        ("✔︎ Bottle Manifest brotli (1.2.1)", "Fetched Bottle Manifest brotli (1.2.1)"),
        ("Removing: /opt/homebrew/Cellar/node/22.1.0... (2,000 files, 70MB)", nil),
    ]
    for (line, expected) in cases {
        let step = BrewService.progressStep(from: line)
        assert(step == expected, "progressStep(\"\(line)\") = \(String(describing: step)), expected \(String(describing: expected))")
    }
    print("✅ testProgressStep Passed")
}

func testLineSplitter() {
    print("Running testLineSplitter...")
    var splitter = LineSplitter()
    assert(splitter.append("==> Down".data(using: .utf8)!) == [], "Partial line should be held back")
    assert(splitter.append("loading\n==> Pour".data(using: .utf8)!) == ["==> Downloading"], "Completed line should be emitted")
    assert(splitter.append("ing\r\n".data(using: .utf8)!) == ["==> Pouring"], "CRLF should end a line once")
    assert(splitter.append("tail".data(using: .utf8)!) == [], "Unterminated line should wait")
    assert(splitter.flush() == ["tail"], "Flush should emit the remaining text")
    print("✅ testLineSplitter Passed")
}

func testFailureReason() {
    print("Running testFailureReason...")
    let result = BrewCommandResult(status: 1, lines: ["==> Upgrading foo", "Error: foo is pinned", "  hint"])
    assert(result.failureReason == "Error: foo is pinned", "Should prefer brew's Error: line")
    assert(BrewCommandResult(status: 3, lines: []).failureReason == "brew exited with status 3", "Should fall back to exit status")
    print("✅ testFailureReason Passed")
}

func testParsePinned() {
    print("Running testParsePinned...")
    let json = """
        {"formulae": [{"name": "python@3.12", "installed_versions": ["3.12.1"], "current_version": "3.12.2", "pinned": true, "pinned_version": "3.12.1"}], "casks": []}
        """
    let packages = try! BrewService.parse(data: json.data(using: .utf8)!)
    assert(packages.first?.pinned == true, "Pinned formula should be flagged")
    print("✅ testParsePinned Passed")
}

func testProgressFraction() {
    print("Running testProgressFraction...")
    assert(BrewService.progressFraction(forStep: "Fetched Bottle node (22.2.0)") == 0.25, "Fetch phase")
    assert(BrewService.progressFraction(forStep: "Upgrading node 22.1.0 -> 22.2.0") == 0.5, "Upgrade phase")
    assert(BrewService.progressFraction(forStep: "Pouring") == 0.7, "Pour phase")
    assert(BrewService.progressFraction(forStep: "Installed") == 0.9, "Installed phase")
    assert(BrewService.progressFraction(forStep: "Error: node is pinned") == nil, "Errors don't move the bar")
    print("✅ testProgressFraction Passed")
}

// Run Tests
testParseValidJSON()
testParseEmptyJSON()
testParseServices()
testProgressStep()
testLineSplitter()
testFailureReason()
testParsePinned()
testProgressFraction()
print("🎉 All tests passed!")
