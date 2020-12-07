/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
@testable import Datadog

@available(iOS 13.0, *)
class DataMigratorBenchmarkTests: XCTestCase {
    private let benchmarkOptions: XCTMeasureOptions = {
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        return options
    }()
    private let benchmarkMetrics: [XCTMetric] = [XCTClockMetric(), XCTMemoryMetric()]

    func testMigrating1000FilesWithDeleteAllDataMigrator() throws {
        let directory = try Directory(withSubdirectoryPath: UUID().uuidString)
        defer { directory.delete() }

        measure(metrics: benchmarkMetrics, options: benchmarkOptions) {
            createFiles(in: directory, count: 1_000)

            self.startMeasuring()
            let migrator = DeleteAllDataMigrator(directory: directory)
            migrator.migrate()
            self.stopMeasuring()
        }
    }

    func testMigrating1000FilesWithMoveDataMigratorTests() throws {
        let sourceDirectory = try Directory(withSubdirectoryPath: UUID().uuidString)
        let destinationDirectory = try Directory(withSubdirectoryPath: UUID().uuidString)
        defer {
            sourceDirectory.delete()
            destinationDirectory.delete()
        }

        measure(metrics: benchmarkMetrics, options: benchmarkOptions) {
            createFiles(in: sourceDirectory, count: 1_000)

            self.startMeasuring()
            let migrator = MoveDataMigrator(sourceDirectory: sourceDirectory, destinationDirectory: destinationDirectory)
            migrator.migrate()
            self.stopMeasuring()
        }
    }

    private func createFiles(in directory: Directory, count: Int) {
        (0..<count).forEach { iteration in
            _ = try! directory.createFile(named: "file\(iteration)")
        }
    }
}
