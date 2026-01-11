import Testing
@testable import PointAppDomain

/// PointAmount（ポイント金額）のテスト
/// ビジネスルール：ポイントは0以上の整数、10pt = 1円
@Suite("PointAmount - ポイント金額の値オブジェクト")
struct PointAmountTests {

    // MARK: - 生成

    @Test("正の値でPointAmountを作成できる")
    func 正の値で作成できる() throws {
        // Act
        let points = try PointAmount(100)

        // Assert
        #expect(points.value == 100)
    }

    @Test("0でPointAmountを作成できる")
    func ゼロで作成できる() throws {
        // Act
        let points = try PointAmount(0)

        // Assert
        #expect(points.value == 0)
    }

    @Test("負の値の場合はエラー")
    func 負の値はエラー() {
        // Act & Assert
        #expect(throws: PointAmountError.negativeValue) {
            try PointAmount(-1)
        }
    }

    // MARK: - 円換算

    @Test("10ポイント = 1円で換算できる")
    func 円換算() throws {
        // Arrange
        let points = try PointAmount(100)

        // Act
        let yen = points.toYen()

        // Assert
        #expect(yen == 10) // 100pt = 10円
    }

    @Test("端数を含む円換算ができる")
    func 端数を含む円換算() throws {
        // Arrange
        let points = try PointAmount(15)

        // Act
        let yen = points.toYen()

        // Assert
        #expect(yen == 1.5) // 15pt = 1.5円
    }

    // MARK: - 加算

    @Test("2つのPointAmountを加算できる")
    func 加算() throws {
        // Arrange
        let points1 = try PointAmount(100)
        let points2 = try PointAmount(50)

        // Act
        let result = points1.adding(points2)

        // Assert
        #expect(result.value == 150)
    }

    // MARK: - 比較

    @Test("2つのPointAmountを比較できる")
    func 比較() throws {
        // Arrange
        let smaller = try PointAmount(50)
        let larger = try PointAmount(100)

        // Assert
        #expect(smaller < larger)
        #expect(larger > smaller)
        #expect(smaller == try PointAmount(50))
    }

    // MARK: - 表示

    @Test("円表示の文字列を取得できる")
    func 円表示文字列() throws {
        // Arrange
        let points = try PointAmount(1234)

        // Act
        let yenString = points.toYenString()

        // Assert
        #expect(yenString == "123.4円")
    }
}
