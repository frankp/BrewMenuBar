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

// Run Tests
testParseValidJSON()
testParseEmptyJSON()
testParseServices()
print("🎉 All tests passed!")
