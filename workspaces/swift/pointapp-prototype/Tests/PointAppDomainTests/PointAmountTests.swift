import XCTest
@testable import PointAppDomain

/// PointAmount（ポイント金額）のテスト
/// ビジネスルール：ポイントは0以上の整数、10pt = 1円
final class PointAmountTests: XCTestCase {

    // MARK: - 生成

    func test_正の値でPointAmountを作成できる() throws {
        // Act
        let points = try PointAmount(100)

        // Assert
        XCTAssertEqual(points.value, 100)
    }

    func test_ゼロでPointAmountを作成できる() throws {
        // Act
        let points = try PointAmount(0)

        // Assert
        XCTAssertEqual(points.value, 0)
    }

    func test_負の値の場合はエラー() {
        // Act & Assert
        XCTAssertThrowsError(try PointAmount(-1)) { error in
            XCTAssertEqual(error as? PointAmountError, .negativeValue)
        }
    }

    // MARK: - 円換算

    func test_10ポイントは1円で換算できる() throws {
        // Arrange
        let points = try PointAmount(100)

        // Act
        let yen = points.toYen()

        // Assert
        XCTAssertEqual(yen, 10) // 100pt = 10円
    }

    func test_端数を含む円換算ができる() throws {
        // Arrange
        let points = try PointAmount(15)

        // Act
        let yen = points.toYen()

        // Assert
        XCTAssertEqual(yen, 1.5) // 15pt = 1.5円
    }

    // MARK: - 加算

    func test_2つのPointAmountを加算できる() throws {
        // Arrange
        let points1 = try PointAmount(100)
        let points2 = try PointAmount(50)

        // Act
        let result = points1.adding(points2)

        // Assert
        XCTAssertEqual(result.value, 150)
    }

    // MARK: - 比較

    func test_2つのPointAmountを比較できる() throws {
        // Arrange
        let smaller = try PointAmount(50)
        let larger = try PointAmount(100)

        // Assert
        XCTAssertTrue(smaller < larger)
        XCTAssertTrue(larger > smaller)
        XCTAssertEqual(smaller, try PointAmount(50))
    }

    // MARK: - 表示

    func test_円表示の文字列を取得できる() throws {
        // Arrange
        let points = try PointAmount(1234)

        // Act
        let yenString = points.toYenString()

        // Assert
        XCTAssertEqual(yenString, "123.4円")
    }
}
