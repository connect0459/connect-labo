# RustでTCP/IPスタックをTDDで実装する - テスト駆動ハンズオン

このハンズオンでは、t-wada流のテスト駆動開発（TDD）を実践しながら、Rustで基礎的なTCP/IPスタックを実装します。**テストコードそのものが仕様書となり、コードの振る舞いを説明するドキュメント**として機能することを目指します。

## TDDの基本サイクル

```text
1. TODOリストを書く（何を作るべきか整理）
2. 一つだけテストを選んで書く（Red: 失敗するテスト）
3. テストを通す最小限のコードを書く（Green: 成功）
4. リファクタリング（きれいにする）
5. 気づいたことをTODOリストに追加
6. 繰り返し
```

**重要**: テストは「動く仕様書」です。後から参加した開発者がテストコードを読めば、システムの振る舞いが理解できる状態を目指します。

## 環境セットアップ

### プロジェクト作成

```bash
cargo new rust-tcp-stack --lib
cd rust-tcp-stack
```

### Cargo.toml設定

```toml
[package]
name = "rust-tcp-stack"
version = "0.1.0"
edition = "2021"

[dependencies]
libc = "0.2"

[dev-dependencies]
# テストで使用
```

### ディレクトリ構造

```text
rust-tcp-stack/
├── Cargo.toml
├── src/
│   ├── lib.rs              # ライブラリルート
│   ├── ethernet.rs         # Ethernet層
│   ├── ipv4.rs            # IP層
│   ├── tcp.rs             # TCP層
│   └── tun_tap.rs         # TUN/TAPデバイス
└── tests/
    ├── ethernet_test.rs    # Ethernet統合テスト
    ├── ipv4_test.rs       # IPv4統合テスト
    └── tcp_test.rs        # TCP統合テスト
```

## Phase 1: Ethernetフレーム - TDDで実装

### TODOリスト-1

```text
Phase 1: Ethernet
□ MACアドレスを表現できる
□ MACアドレスを文字列表示できる
□ ブロードキャストMACアドレスを作れる
□ Ethernetフレームをパースできる
  □ 最小長（14バイト）未満は失敗
  □ 送信元MACアドレスを取得できる
  □ 宛先MACアドレスを取得できる
  □ EtherTypeを取得できる（IPv4）
  □ ペイロードを取得できる
□ Ethernetフレームを構築できる
  □ ヘッダー + ペイロードを結合
  □ 正しいバイト列になっている
```

### Step 1: MACアドレス表現（Red → Green → Refactor）

**src/ethernet.rs**を作成:

```rust
use std::fmt;

/// MACアドレス（6バイト）を表現する型
/// 
/// # Examples
/// ```
/// use rust_tcp_tdd::ethernet::MacAddress;
/// let mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
/// assert_eq!(format!("{}", mac), "00:11:22:33:44:55");
/// ```
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MacAddress(pub [u8; 6]);

impl MacAddress {
    /// 新しいMACアドレスを作成
    pub fn new(bytes: [u8; 6]) -> Self {
        MacAddress(bytes)
    }

    /// ブロードキャストアドレス（ff:ff:ff:ff:ff:ff）を返す
    pub fn broadcast() -> Self {
        MacAddress([0xff; 6])
    }
}

impl fmt::Display for MacAddress {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "{:02x}:{:02x}:{:02x}:{:02x}:{:02x}:{:02x}",
            self.0[0], self.0[1], self.0[2], self.0[3], self.0[4], self.0[5]
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// テスト階層: Ethernet > MACアドレス > 基本操作
    mod mac_address {
        use super::*;

        #[test]
        fn 新しいmacアドレスを作成できる() {
            let mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
            assert_eq!(mac.0, [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
        }

        #[test]
        fn macアドレスを文字列表示できる() {
            let mac = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
            assert_eq!(format!("{}", mac), "aa:bb:cc:dd:ee:ff");
        }

        #[test]
        fn ブロードキャストアドレスを作成できる() {
            let broadcast = MacAddress::broadcast();
            assert_eq!(broadcast.0, [0xff; 6]);
            assert_eq!(format!("{}", broadcast), "ff:ff:ff:ff:ff:ff");
        }

        #[test]
        fn macアドレスの等価性を判定できる() {
            let mac1 = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
            let mac2 = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
            let mac3 = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x66]);
            
            assert_eq!(mac1, mac2);
            assert_ne!(mac1, mac3);
        }
    }
}
```

**テスト実行**:

```bash
cargo test ethernet::tests::mac_address
```

### Step 2: EtherType定義

```rust
/// Ethernetフレームのタイプを表す
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EtherType {
    Ipv4,      // 0x0800
    Arp,       // 0x0806
    Unknown(u16),
}

impl From<u16> for EtherType {
    fn from(value: u16) -> Self {
        match value {
            0x0800 => EtherType::Ipv4,
            0x0806 => EtherType::Arp,
            _ => EtherType::Unknown(value),
        }
    }
}

impl From<EtherType> for u16 {
    fn from(value: EtherType) -> Self {
        match value {
            EtherType::Ipv4 => 0x0800,
            EtherType::Arp => 0x0806,
            EtherType::Unknown(v) => v,
        }
    }
}

#[cfg(test)]
mod ether_type_tests {
    use super::*;

    /// テスト階層: Ethernet > EtherType > 変換
    #[test]
    fn ipv4のethertypeに変換できる() {
        assert_eq!(EtherType::from(0x0800), EtherType::Ipv4);
        assert_eq!(u16::from(EtherType::Ipv4), 0x0800);
    }

    #[test]
    fn arpのethertypeに変換できる() {
        assert_eq!(EtherType::from(0x0806), EtherType::Arp);
        assert_eq!(u16::from(EtherType::Arp), 0x0806);
    }

    #[test]
    fn 未知のethertypeを扱える() {
        assert_eq!(EtherType::from(0x9999), EtherType::Unknown(0x9999));
        assert_eq!(u16::from(EtherType::Unknown(0x9999)), 0x9999);
    }
}
```

### Step 3: Ethernetフレームパーサー（TDD）

```rust
/// Ethernetフレームのパーサー
/// 
/// # フレーム構造
/// ```text
/// +-------------------+-------------------+----------+-------+
/// | Destination MAC   | Source MAC        | EtherType| Data  |
/// | (6 bytes)        | (6 bytes)         | (2 bytes)|       |
/// +-------------------+-------------------+----------+-------+
/// ```
pub struct EthernetFrame<'a> {
    data: &'a [u8],
}

impl<'a> EthernetFrame<'a> {
    /// バイト列からEthernetフレームを作成
    /// 
    /// # 失敗条件
    /// - データが14バイト未満の場合
    pub fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 14 {
            return None;
        }
        Some(EthernetFrame { data })
    }

    pub fn destination(&self) -> MacAddress {
        let mut bytes = [0u8; 6];
        bytes.copy_from_slice(&self.data[0..6]);
        MacAddress(bytes)
    }

    pub fn source(&self) -> MacAddress {
        let mut bytes = [0u8; 6];
        bytes.copy_from_slice(&self.data[6..12]);
        MacAddress(bytes)
    }

    pub fn ether_type(&self) -> EtherType {
        let value = u16::from_be_bytes([self.data[12], self.data[13]]);
        EtherType::from(value)
    }

    pub fn payload(&self) -> &[u8] {
        &self.data[14..]
    }
}

#[cfg(test)]
mod frame_parser_tests {
    use super::*;

    /// テスト階層: Ethernet > フレームパース > バリデーション
    mod validation {
        use super::*;

        #[test]
        fn 最小長未満のデータは失敗する() {
            let short_data = [0u8; 13];
            assert!(EthernetFrame::new(&short_data).is_none());
        }

        #[test]
        fn 最小長のデータは成功する() {
            let min_data = [0u8; 14];
            assert!(EthernetFrame::new(&min_data).is_some());
        }

        #[test]
        fn ペイロード付きデータは成功する() {
            let data_with_payload = [0u8; 100];
            assert!(EthernetFrame::new(&data_with_payload).is_some());
        }
    }

    /// テスト階層: Ethernet > フレームパース > フィールド抽出
    mod field_extraction {
        use super::*;

        #[test]
        fn 宛先macアドレスを取得できる() {
            let mut data = [0u8; 14];
            data[0..6].copy_from_slice(&[0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
            
            let frame = EthernetFrame::new(&data).unwrap();
            let expected = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
            assert_eq!(frame.destination(), expected);
        }

        #[test]
        fn 送信元macアドレスを取得できる() {
            let mut data = [0u8; 14];
            data[6..12].copy_from_slice(&[0x11, 0x22, 0x33, 0x44, 0x55, 0x66]);
            
            let frame = EthernetFrame::new(&data).unwrap();
            let expected = MacAddress::new([0x11, 0x22, 0x33, 0x44, 0x55, 0x66]);
            assert_eq!(frame.source(), expected);
        }

        #[test]
        fn ethertypeがipv4の場合を取得できる() {
            let mut data = [0u8; 14];
            data[12] = 0x08;
            data[13] = 0x00;
            
            let frame = EthernetFrame::new(&data).unwrap();
            assert_eq!(frame.ether_type(), EtherType::Ipv4);
        }

        #[test]
        fn ペイロードを取得できる() {
            let mut data = vec![0u8; 20];
            data[14..20].copy_from_slice(b"Hello!");
            
            let frame = EthernetFrame::new(&data).unwrap();
            assert_eq!(frame.payload(), b"Hello!");
        }
    }

    /// テスト階層: Ethernet > フレームパース > 実際のパケット例
    mod realistic_packets {
        use super::*;

        #[test]
        fn 実際のipv4フレームをパースできる() {
            // 実際のEthernetフレームの例
            let packet = [
                // Destination MAC
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                // Source MAC
                0x00, 0x11, 0x22, 0x33, 0x44, 0x55,
                // EtherType (IPv4)
                0x08, 0x00,
                // Payload
                0x45, 0x00, 0x00, 0x3c, // IPv4 header始まり
            ];

            let frame = EthernetFrame::new(&packet).unwrap();
            
            assert_eq!(frame.destination(), MacAddress::broadcast());
            assert_eq!(frame.source(), MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]));
            assert_eq!(frame.ether_type(), EtherType::Ipv4);
            assert_eq!(frame.payload().len(), 4);
        }
    }
}
```

### Step 4: Ethernetフレームビルダー（TDD）

```rust
/// Ethernetフレームを構築するビルダー
pub struct EthernetFrameBuilder {
    buffer: Vec<u8>,
}

impl EthernetFrameBuilder {
    /// 新しいフレームビルダーを作成
    /// 
    /// # Examples
    /// ```
    /// use rust_tcp_tdd::ethernet::{EthernetFrameBuilder, MacAddress, EtherType};
    /// 
    /// let src = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    /// let dst = MacAddress::broadcast();
    /// 
    /// let frame = EthernetFrameBuilder::new(dst, src, EtherType::Ipv4)
    ///     .payload(b"Hello")
    ///     .build();
    /// 
    /// assert_eq!(frame.len(), 14 + 5);
    /// ```
    pub fn new(dst: MacAddress, src: MacAddress, ether_type: EtherType) -> Self {
        let mut buffer = Vec::with_capacity(1514);
        
        // Destination MAC
        buffer.extend_from_slice(&dst.0);
        
        // Source MAC
        buffer.extend_from_slice(&src.0);
        
        // EtherType
        let et: u16 = ether_type.into();
        buffer.extend_from_slice(&et.to_be_bytes());
        
        EthernetFrameBuilder { buffer }
    }

    /// ペイロードを追加
    pub fn payload(mut self, data: &[u8]) -> Self {
        self.buffer.extend_from_slice(data);
        self
    }

    /// フレームを構築して返す
    pub fn build(self) -> Vec<u8> {
        self.buffer
    }
}

#[cfg(test)]
mod frame_builder_tests {
    use super::*;

    /// テスト階層: Ethernet > フレーム構築 > 基本構築
    mod basic_construction {
        use super::*;

        #[test]
        fn ペイロードなしのフレームを構築できる() {
            let src = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
            let dst = MacAddress::broadcast();
            
            let frame = EthernetFrameBuilder::new(dst, src, EtherType::Ipv4)
                .build();
            
            assert_eq!(frame.len(), 14);
        }

        #[test]
        fn ペイロード付きフレームを構築できる() {
            let src = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
            let dst = MacAddress::broadcast();
            
            let frame = EthernetFrameBuilder::new(dst, src, EtherType::Ipv4)
                .payload(b"Hello, Ethernet!")
                .build();
            
            assert_eq!(frame.len(), 14 + 16);
        }
    }

    /// テスト階層: Ethernet > フレーム構築 > 正確性検証
    mod correctness {
        use super::*;

        #[test]
        fn 構築したフレームをパースして検証できる() {
            let src = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
            let dst = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
            
            let frame_bytes = EthernetFrameBuilder::new(dst, src, EtherType::Ipv4)
                .payload(b"Test payload")
                .build();
            
            // 構築したフレームをパースして検証
            let frame = EthernetFrame::new(&frame_bytes).unwrap();
            assert_eq!(frame.destination(), dst);
            assert_eq!(frame.source(), src);
            assert_eq!(frame.ether_type(), EtherType::Ipv4);
            assert_eq!(frame.payload(), b"Test payload");
        }

        #[test]
        fn 構築したフレームのバイト配置が正しい() {
            let src = MacAddress::new([0x11, 0x22, 0x33, 0x44, 0x55, 0x66]);
            let dst = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
            
            let frame = EthernetFrameBuilder::new(dst, src, EtherType::Ipv4)
                .build();
            
            // バイト配置を直接検証
            assert_eq!(&frame[0..6], &[0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
            assert_eq!(&frame[6..12], &[0x11, 0x22, 0x33, 0x44, 0x55, 0x66]);
            assert_eq!(&frame[12..14], &[0x08, 0x00]); // IPv4
        }
    }
}
```

### src/lib.rsの設定

```rust
pub mod ethernet;
pub mod ipv4;
pub mod tcp;
pub mod tun_tap;
```

**テスト実行とTODO確認**:

```bash
# 全Ethernetテストを実行
cargo test ethernet

# テスト結果を見てTODOリストにチェックを入れる
```

## Phase 2: IPv4パケット - TDDで実装

### TODOリスト-2

```text
Phase 2: IPv4
□ IPv4アドレスを扱える（std::net::Ipv4Addrを使用）
□ プロトコル番号を扱える（TCP, UDP, ICMP）
□ IPv4パケットをパースできる
  □ 最小長（20バイト）未満は失敗
  □ バージョン4以外は失敗
  □ 送信元IPアドレスを取得できる
  □ 宛先IPアドレスを取得できる
  □ プロトコルを取得できる
  □ ペイロードを取得できる
  □ チェックサムを検証できる
□ IPv4パケットを構築できる
  □ 正しいヘッダーを生成
  □ チェックサムを自動計算
  □ パース→ビルドの往復で同じになる
```

### Step 1: プロトコル定義（Red → Green）

**src/ipv4.rs**:

```rust
use std::net::Ipv4Addr;

/// IPv4のプロトコル番号を表す
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IpProtocol {
    Icmp,      // 1
    Tcp,       // 6
    Udp,       // 17
    Unknown(u8),
}

impl From<u8> for IpProtocol {
    fn from(value: u8) -> Self {
        match value {
            1 => IpProtocol::Icmp,
            6 => IpProtocol::Tcp,
            17 => IpProtocol::Udp,
            _ => IpProtocol::Unknown(value),
        }
    }
}

impl From<IpProtocol> for u8 {
    fn from(value: IpProtocol) -> Self {
        match value {
            IpProtocol::Icmp => 1,
            IpProtocol::Tcp => 6,
            IpProtocol::Udp => 17,
            IpProtocol::Unknown(v) => v,
        }
    }
}

#[cfg(test)]
mod protocol_tests {
    use super::*;

    /// テスト階層: IPv4 > プロトコル > 変換
    mod conversion {
        use super::*;

        #[test]
        fn tcpプロトコルに変換できる() {
            assert_eq!(IpProtocol::from(6), IpProtocol::Tcp);
            assert_eq!(u8::from(IpProtocol::Tcp), 6);
        }

        #[test]
        fn udpプロトコルに変換できる() {
            assert_eq!(IpProtocol::from(17), IpProtocol::Udp);
            assert_eq!(u8::from(IpProtocol::Udp), 17);
        }

        #[test]
        fn icmpプロトコルに変換できる() {
            assert_eq!(IpProtocol::from(1), IpProtocol::Icmp);
            assert_eq!(u8::from(IpProtocol::Icmp), 1);
        }

        #[test]
        fn 未知のプロトコルを扱える() {
            assert_eq!(IpProtocol::from(99), IpProtocol::Unknown(99));
            assert_eq!(u8::from(IpProtocol::Unknown(99)), 99);
        }
    }
}
```

### Step 2: チェックサム計算（TDD）

```rust
/// IPv4ヘッダーのチェックサムを計算
/// 
/// # アルゴリズム
/// 1. ヘッダーを16ビットワードの列として扱う
/// 2. すべてのワードを加算（キャリーは折り返す）
/// 3. 結果のビット反転
pub fn calculate_checksum(data: &[u8]) -> u16 {
    let mut sum: u32 = 0;
    
    // 16ビットずつ加算
    for i in (0..data.len()).step_by(2) {
        let word = if i + 1 < data.len() {
            u16::from_be_bytes([data[i], data[i + 1]]) as u32
        } else {
            (data[i] as u32) << 8
        };
        sum += word;
    }

    // キャリーを折り返す
    while (sum >> 16) != 0 {
        sum = (sum & 0xffff) + (sum >> 16);
    }

    // ビット反転
    !sum as u16
}

#[cfg(test)]
mod checksum_tests {
    use super::*;

    /// テスト階層: IPv4 > チェックサム > 計算
    mod calculation {
        use super::*;

        #[test]
        fn 空データのチェックサムは0xffffになる() {
            let data = [];
            assert_eq!(calculate_checksum(&data), 0xffff);
        }

        #[test]
        fn 単純なデータのチェックサムを計算できる() {
            let data = [0x00, 0x01];
            let checksum = calculate_checksum(&data);
            assert_eq!(checksum, 0xfffe);
        }

        #[test]
        fn キャリーを含む計算ができる() {
            let data = [0xff, 0xff, 0xff, 0xff];
            let checksum = calculate_checksum(&data);
            assert_eq!(checksum, 0x0000);
        }

        #[test]
        fn 奇数長データのチェックサムを計算できる() {
            let data = [0x12, 0x34, 0x56];
            let checksum = calculate_checksum(&data);
            // 0x1234 + 0x5600 = 0x6834
            // !0x6834 = 0x97cb
            assert_eq!(checksum, 0x97cb);
        }

        #[test]
        fn 正しいチェックサムを含むデータの検証結果は0になる() {
            // チェックサムフィールドを含む完全なヘッダー
            let mut header = vec![0x45, 0x00, 0x00, 0x3c, 0x1c, 0x46, 0x40, 0x00,
                                 0x40, 0x06, 0x00, 0x00, 0xac, 0x10, 0x0a, 0x63,
                                 0xac, 0x10, 0x0a, 0x0c];
            
            // チェックサムを計算して埋める
            let checksum = calculate_checksum(&header);
            header[10] = (checksum >> 8) as u8;
            header[11] = (checksum & 0xff) as u8;
            
            // チェックサム込みで検証すると0になる
            assert_eq!(calculate_checksum(&header), 0);
        }
    }
}
```

### Step 3: IPv4パケットパーサー（TDD）

```rust
/// IPv4パケットのパーサー
/// 
/// # パケット構造
/// ```text
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |Version|  IHL  |Type of Service|          Total Length         |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |         Identification        |Flags|      Fragment Offset    |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |  Time to Live |    Protocol   |         Header Checksum       |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                       Source Address                          |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                    Destination Address                        |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// ```
pub struct Ipv4Packet<'a> {
    data: &'a [u8],
}

impl<'a> Ipv4Packet<'a> {
    /// バイト列からIPv4パケットを作成
    /// 
    /// # 失敗条件
    /// - データが20バイト未満
    /// - バージョンが4でない
    pub fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 20 {
            return None;
        }
        
        let version = data[0] >> 4;
        if version != 4 {
            return None;
        }

        Some(Ipv4Packet { data })
    }

    pub fn version(&self) -> u8 {
        self.data[0] >> 4
    }

    pub fn header_length(&self) -> usize {
        ((self.data[0] & 0x0f) * 4) as usize
    }

    pub fn total_length(&self) -> u16 {
        u16::from_be_bytes([self.data[2], self.data[3]])
    }

    pub fn protocol(&self) -> IpProtocol {
        IpProtocol::from(self.data[9])
    }

    pub fn source(&self) -> Ipv4Addr {
        Ipv4Addr::new(self.data[12], self.data[13], self.data[14], self.data[15])
    }

    pub fn destination(&self) -> Ipv4Addr {
        Ipv4Addr::new(self.data[16], self.data[17], self.data[18], self.data[19])
    }

    pub fn checksum(&self) -> u16 {
        u16::from_be_bytes([self.data[10], self.data[11]])
    }

    pub fn verify_checksum(&self) -> bool {
        let header_len = self.header_length();
        calculate_checksum(&self.data[..header_len]) == 0
    }

    pub fn payload(&self) -> &[u8] {
        let header_len = self.header_length();
        &self.data[header_len..]
    }
}

#[cfg(test)]
mod packet_parser_tests {
    use super::*;

    /// テスト階層: IPv4 > パケットパース > バリデーション
    mod validation {
        use super::*;

        #[test]
        fn 最小長未満のデータは失敗する() {
            let short_data = [0u8; 19];
            assert!(Ipv4Packet::new(&short_data).is_none());
        }

        #[test]
        fn バージョン4以外は失敗する() {
            let mut data = [0u8; 20];
            data[0] = 0x60; // Version 6
            assert!(Ipv4Packet::new(&data).is_none());
        }

        #[test]
        fn 正しいipv4パケットは成功する() {
            let mut data = [0u8; 20];
            data[0] = 0x45; // Version 4, IHL 5
            assert!(Ipv4Packet::new(&data).is_some());
        }
    }

    /// テスト階層: IPv4 > パケットパース > フィールド抽出
    mod field_extraction {
        use super::*;

        #[test]
        fn バージョンを取得できる() {
            let mut data = [0u8; 20];
            data[0] = 0x45;
            let packet = Ipv4Packet::new(&data).unwrap();
            assert_eq!(packet.version(), 4);
        }

        #[test]
        fn ヘッダー長を取得できる() {
            let mut data = [0u8; 20];
            data[0] = 0x45; // IHL = 5 → 20 bytes
            let packet = Ipv4Packet::new(&data).unwrap();
            assert_eq!(packet.header_length(), 20);
        }

        #[test]
        fn プロトコルを取得できる() {
            let mut data = [0u8; 20];
            data[0] = 0x45;
            data[9] = 6; // TCP
            let packet = Ipv4Packet::new(&data).unwrap();
            assert_eq!(packet.protocol(), IpProtocol::Tcp);
        }

        #[test]
        fn 送信元ipアドレスを取得できる() {
            let mut data = [0u8; 20];
            data[0] = 0x45;
            data[12..16].copy_from_slice(&[192, 168, 1, 100]);
            let packet = Ipv4Packet::new(&data).unwrap();
            assert_eq!(packet.source(), Ipv4Addr::new(192, 168, 1, 100));
        }

        #[test]
        fn 宛先ipアドレスを取得できる() {
            let mut data = [0u8; 20];
            data[0] = 0x45;
            data[16..20].copy_from_slice(&[192, 168, 1, 1]);
            let packet = Ipv4Packet::new(&data).unwrap();
            assert_eq!(packet.destination(), Ipv4Addr::new(192, 168, 1, 1));
        }

        #[test]
        fn ペイロードを取得できる() {
            let mut data = vec![0u8; 30];
            data[0] = 0x45;
            data[20..30].copy_from_slice(b"HelloWorld");
            let packet = Ipv4Packet::new(&data).unwrap();
            assert_eq!(packet.payload(), b"HelloWorld");
        }
    }

    /// テスト階層: IPv4 > パケットパース > チェックサム検証
    mod checksum_verification {
        use super::*;

        #[test]
        fn 正しいチェックサムは検証に成功する() {
            let mut data = vec![
                0x45, 0x00, 0x00, 0x3c, 0x1c, 0x46, 0x40, 0x00,
                0x40, 0x06, 0x00, 0x00, 0xac, 0x10, 0x0a, 0x63,
                0xac, 0x10, 0x0a, 0x0c,
            ];
            
            // チェックサムを計算
            let checksum = calculate_checksum(&data);
            data[10] = (checksum >> 8) as u8;
            data[11] = (checksum & 0xff) as u8;
            
            let packet = Ipv4Packet::new(&data).unwrap();
            assert!(packet.verify_checksum());
        }

        #[test]
        fn 誤ったチェックサムは検証に失敗する() {
            let mut data = vec![0x45, 0x00, 0x00, 0x3c, 0x1c, 0x46, 0x40, 0x00,
                               0x40, 0x06, 0x00, 0x00, 0xac, 0x10, 0x0a, 0x63,
                               0xac, 0x10, 0x0a, 0x0c];
            
            data[10] = 0xff; // 誤ったチェックサム
            data[11] = 0xff;
            
            let packet = Ipv4Packet::new(&data).unwrap();
            assert!(!packet.verify_checksum());
        }
    }
}
```

### Step 4: IPv4パケットビルダー（TDD）

```rust
/// IPv4パケットを構築するビルダー
pub struct Ipv4PacketBuilder {
    source: Ipv4Addr,
    destination: Ipv4Addr,
    protocol: IpProtocol,
    ttl: u8,
    payload: Vec<u8>,
}

impl Ipv4PacketBuilder {
    pub fn new(source: Ipv4Addr, destination: Ipv4Addr, protocol: IpProtocol) -> Self {
        Ipv4PacketBuilder {
            source,
            destination,
            protocol,
            ttl: 64,
            payload: Vec::new(),
        }
    }

    pub fn ttl(mut self, ttl: u8) -> Self {
        self.ttl = ttl;
        self
    }

    pub fn payload(mut self, data: &[u8]) -> Self {
        self.payload = data.to_vec();
        self
    }

    pub fn build(self) -> Vec<u8> {
        let total_length = 20 + self.payload.len();
        let mut packet = vec![0u8; total_length];

        // Version (4) + IHL (5 = 20 bytes)
        packet[0] = 0x45;
        
        // Total Length
        packet[2..4].copy_from_slice(&(total_length as u16).to_be_bytes());
        
        // TTL
        packet[8] = self.ttl;
        
        // Protocol
        packet[9] = self.protocol.into();
        
        // Source IP
        packet[12..16].copy_from_slice(&self.source.octets());
        
        // Destination IP
        packet[16..20].copy_from_slice(&self.destination.octets());
        
        // Calculate and set checksum
        let checksum = calculate_checksum(&packet[..20]);
        packet[10..12].copy_from_slice(&checksum.to_be_bytes());
        
        // Payload
        packet[20..].copy_from_slice(&self.payload);

        packet
    }
}

#[cfg(test)]
mod packet_builder_tests {
    use super::*;

    /// テスト階層: IPv4 > パケット構築 > 基本構築
    mod basic_construction {
        use super::*;

        #[test]
        fn ペイロードなしのパケットを構築できる() {
            let src = Ipv4Addr::new(192, 168, 1, 100);
            let dst = Ipv4Addr::new(192, 168, 1, 1);
            
            let packet = Ipv4PacketBuilder::new(src, dst, IpProtocol::Tcp)
                .build();
            
            assert_eq!(packet.len(), 20);
        }

        #[test]
        fn ペイロード付きパケットを構築できる() {
            let src = Ipv4Addr::new(10, 0, 0, 1);
            let dst = Ipv4Addr::new(10, 0, 0, 2);
            
            let packet = Ipv4PacketBuilder::new(src, dst, IpProtocol::Tcp)
                .payload(b"Hello, IPv4!")
                .build();
            
            assert_eq!(packet.len(), 20 + 12);
        }

        #[test]
        fn ttlをカスタマイズできる() {
            let src = Ipv4Addr::new(192, 168, 1, 100);
            let dst = Ipv4Addr::new(192, 168, 1, 1);
            
            let packet = Ipv4PacketBuilder::new(src, dst, IpProtocol::Tcp)
                .ttl(128)
                .build();
            
            let parsed = Ipv4Packet::new(&packet).unwrap();
            // TTLは8バイト目
            assert_eq!(packet[8], 128);
        }
    }

    /// テスト階層: IPv4 > パケット構築 > 正確性検証
    mod correctness {
        use super::*;

        #[test]
        fn 構築したパケットをパースして検証できる() {
            let src = Ipv4Addr::new(172, 16, 0, 1);
            let dst = Ipv4Addr::new(172, 16, 0, 2);
            
            let packet_bytes = Ipv4PacketBuilder::new(src, dst, IpProtocol::Udp)
                .payload(b"Test data")
                .build();
            
            let packet = Ipv4Packet::new(&packet_bytes).unwrap();
            assert_eq!(packet.source(), src);
            assert_eq!(packet.destination(), dst);
            assert_eq!(packet.protocol(), IpProtocol::Udp);
            assert_eq!(packet.payload(), b"Test data");
        }

        #[test]
        fn 構築したパケットのチェックサムは正しい() {
            let src = Ipv4Addr::new(192, 168, 100, 50);
            let dst = Ipv4Addr::new(8, 8, 8, 8);
            
            let packet_bytes = Ipv4PacketBuilder::new(src, dst, IpProtocol::Tcp)
                .build();
            
            let packet = Ipv4Packet::new(&packet_bytes).unwrap();
            assert!(packet.verify_checksum());
        }

        #[test]
        fn パース_ビルド_パースの往復で同じになる() {
            let src = Ipv4Addr::new(10, 20, 30, 40);
            let dst = Ipv4Addr::new(50, 60, 70, 80);
            let payload = b"Round trip test";
            
            let original = Ipv4PacketBuilder::new(src, dst, IpProtocol::Icmp)
                .ttl(100)
                .payload(payload)
                .build();
            
            let parsed = Ipv4Packet::new(&original).unwrap();
            
            let rebuilt = Ipv4PacketBuilder::new(
                parsed.source(),
                parsed.destination(),
                parsed.protocol()
            )
            .ttl(100)
            .payload(parsed.payload())
            .build();
            
            assert_eq!(original, rebuilt);
        }
    }
}
```

## Phase 3: TCP - TDDで実装

### TODOリスト-3

```text
Phase 3: TCP
□ TCPフラグを扱える（SYN, ACK, FIN, RST, PSH, URG）
□ TCPパケットをパースできる
  □ 最小長（20バイト）未満は失敗
  □ ポート番号を取得できる
  □ シーケンス番号を取得できる
  □ 確認応答番号を取得できる
  □ フラグを取得できる
  □ ウィンドウサイズを取得できる
  □ ペイロードを取得できる
  □ チェックサムを検証できる（疑似ヘッダー含む）
□ TCPパケットを構築できる
  □ 正しいヘッダーを生成
  □ チェックサムを自動計算（疑似ヘッダー含む）
  □ SYNパケットを作れる
  □ SYN-ACKパケットを作れる
  □ ACKパケットを作れる
  □ データ転送パケットを作れる
```

### Step 1: TCPフラグ（TDD）

**src/tcp.rs**:

```rust
use std::net::Ipv4Addr;

/// TCPフラグを表す構造体
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TcpFlags {
    pub fin: bool,  // 接続終了
    pub syn: bool,  // 接続確立
    pub rst: bool,  // 接続リセット
    pub psh: bool,  // プッシュ
    pub ack: bool,  // 確認応答
    pub urg: bool,  // 緊急
}

impl TcpFlags {
    pub fn new() -> Self {
        TcpFlags {
            fin: false,
            syn: false,
            rst: false,
            psh: false,
            ack: false,
            urg: false,
        }
    }

    pub fn from_byte(byte: u8) -> Self {
        TcpFlags {
            fin: (byte & 0x01) != 0,
            syn: (byte & 0x02) != 0,
            rst: (byte & 0x04) != 0,
            psh: (byte & 0x08) != 0,
            ack: (byte & 0x10) != 0,
            urg: (byte & 0x20) != 0,
        }
    }

    pub fn to_byte(&self) -> u8 {
        let mut byte = 0u8;
        if self.fin { byte |= 0x01; }
        if self.syn { byte |= 0x02; }
        if self.rst { byte |= 0x04; }
        if self.psh { byte |= 0x08; }
        if self.ack { byte |= 0x10; }
        if self.urg { byte |= 0x20; }
        byte
    }
}

#[cfg(test)]
mod flag_tests {
    use super::*;

    /// テスト階層: TCP > フラグ > 基本操作
    mod basic_operations {
        use super::*;

        #[test]
        fn 新しいフラグはすべてfalse() {
            let flags = TcpFlags::new();
            assert!(!flags.fin);
            assert!(!flags.syn);
            assert!(!flags.rst);
            assert!(!flags.psh);
            assert!(!flags.ack);
            assert!(!flags.urg);
        }

        #[test]
        fn バイトからフラグに変換できる() {
            let flags = TcpFlags::from_byte(0b00010010); // SYN + ACK
            assert!(!flags.fin);
            assert!(flags.syn);
            assert!(!flags.rst);
            assert!(!flags.psh);
            assert!(flags.ack);
            assert!(!flags.urg);
        }

        #[test]
        fn フラグをバイトに変換できる() {
            let mut flags = TcpFlags::new();
            flags.syn = true;
            flags.ack = true;
            assert_eq!(flags.to_byte(), 0b00010010);
        }

        #[test]
        fn バイト変換の往復で同じになる() {
            let original = 0b00111111;
            let flags = TcpFlags::from_byte(original);
            let result = flags.to_byte();
            assert_eq!(result, original);
        }
    }

    /// テスト階層: TCP > フラグ > 典型的なパターン
    mod typical_patterns {
        use super::*;

        #[test]
        fn synパケットのフラグ() {
            let mut flags = TcpFlags::new();
            flags.syn = true;
            assert_eq!(flags.to_byte(), 0x02);
        }

        #[test]
        fn syn_ackパケットのフラグ() {
            let mut flags = TcpFlags::new();
            flags.syn = true;
            flags.ack = true;
            assert_eq!(flags.to_byte(), 0x12);
        }

        #[test]
        fn ackパケットのフラグ() {
            let mut flags = TcpFlags::new();
            flags.ack = true;
            assert_eq!(flags.to_byte(), 0x10);
        }

        #[test]
        fn psh_ackパケットのフラグ() {
            let mut flags = TcpFlags::new();
            flags.psh = true;
            flags.ack = true;
            assert_eq!(flags.to_byte(), 0x18);
        }

        #[test]
        fn finパケットのフラグ() {
            let mut flags = TcpFlags::new();
            flags.fin = true;
            flags.ack = true;
            assert_eq!(flags.to_byte(), 0x11);
        }
    }
}
```

### Step 2: TCPチェックサム（疑似ヘッダー対応）

```rust
/// TCPチェックサムを計算（疑似ヘッダー含む）
/// 
/// # 疑似ヘッダー
/// ```text
/// +--------+--------+--------+--------+
/// |           Source Address          |
/// +--------+--------+--------+--------+
/// |         Destination Address       |
/// +--------+--------+--------+--------+
/// |  zero  |  PTCL  |    TCP Length   |
/// +--------+--------+--------+--------+
/// ```
fn calculate_tcp_checksum(tcp_data: &[u8], src_ip: Ipv4Addr, dst_ip: Ipv4Addr) -> u16 {
    let mut sum: u32 = 0;

    // 疑似ヘッダー: 送信元IP
    for &byte in src_ip.octets().iter() {
        sum += byte as u32;
    }
    
    // 疑似ヘッダー: 宛先IP
    for &byte in dst_ip.octets().iter() {
        sum += byte as u32;
    }
    
    // 疑似ヘッダー: プロトコル（TCP = 6）
    sum += 6;
    
    // 疑似ヘッダー: TCPセグメント長
    sum += tcp_data.len() as u32;

    // TCPヘッダーとデータ
    for i in (0..tcp_data.len()).step_by(2) {
        let word = if i + 1 < tcp_data.len() {
            u16::from_be_bytes([tcp_data[i], tcp_data[i + 1]]) as u32
        } else {
            (tcp_data[i] as u32) << 8
        };
        sum += word;
    }

    // キャリーを折り返す
    while (sum >> 16) != 0 {
        sum = (sum & 0xffff) + (sum >> 16);
    }

    !sum as u16
}

#[cfg(test)]
mod checksum_tests {
    use super::*;

    /// テスト階層: TCP > チェックサム > 計算
    mod calculation {
        use super::*;

        #[test]
        fn 疑似ヘッダーを含むチェックサムを計算できる() {
            let tcp_data = vec![0u8; 20];
            let src = Ipv4Addr::new(192, 168, 1, 1);
            let dst = Ipv4Addr::new(192, 168, 1, 2);
            
            let checksum = calculate_tcp_checksum(&tcp_data, src, dst);
            // チェックサムは0にならない（データがゼロでも疑似ヘッダーがあるため）
            assert_ne!(checksum, 0);
        }

        #[test]
        fn 正しいチェックサムを含むセグメントの検証結果は0になる() {
            let mut tcp_data = vec![0u8; 20];
            let src = Ipv4Addr::new(10, 0, 0, 1);
            let dst = Ipv4Addr::new(10, 0, 0, 2);
            
            // チェックサムを計算して埋める
            let checksum = calculate_tcp_checksum(&tcp_data, src, dst);
            tcp_data[16] = (checksum >> 8) as u8;
            tcp_data[17] = (checksum & 0xff) as u8;
            
            // 再計算すると0になる
            assert_eq!(calculate_tcp_checksum(&tcp_data, src, dst), 0);
        }
    }
}
```

### Step 3: TCPパケットパーサー（TDD）

```rust
/// TCPパケットのパーサー
pub struct TcpPacket<'a> {
    data: &'a [u8],
}

impl<'a> TcpPacket<'a> {
    pub fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 20 {
            return None;
        }
        Some(TcpPacket { data })
    }

    pub fn source_port(&self) -> u16 {
        u16::from_be_bytes([self.data[0], self.data[1]])
    }

    pub fn destination_port(&self) -> u16 {
        u16::from_be_bytes([self.data[2], self.data[3]])
    }

    pub fn sequence_number(&self) -> u32 {
        u32::from_be_bytes([self.data[4], self.data[5], self.data[6], self.data[7]])
    }

    pub fn acknowledgment_number(&self) -> u32 {
        u32::from_be_bytes([self.data[8], self.data[9], self.data[10], self.data[11]])
    }

    pub fn data_offset(&self) -> usize {
        ((self.data[12] >> 4) * 4) as usize
    }

    pub fn flags(&self) -> TcpFlags {
        TcpFlags::from_byte(self.data[13])
    }

    pub fn window_size(&self) -> u16 {
        u16::from_be_bytes([self.data[14], self.data[15]])
    }

    pub fn checksum(&self) -> u16 {
        u16::from_be_bytes([self.data[16], self.data[17]])
    }

    pub fn payload(&self) -> &[u8] {
        let offset = self.data_offset();
        &self.data[offset..]
    }

    pub fn verify_checksum(&self, src_ip: Ipv4Addr, dst_ip: Ipv4Addr) -> bool {
        calculate_tcp_checksum(self.data, src_ip, dst_ip) == 0
    }
}

#[cfg(test)]
mod packet_parser_tests {
    use super::*;

    /// テスト階層: TCP > パケットパース > バリデーション
    mod validation {
        use super::*;

        #[test]
        fn 最小長未満のデータは失敗する() {
            let short_data = [0u8; 19];
            assert!(TcpPacket::new(&short_data).is_none());
        }

        #[test]
        fn 最小長のデータは成功する() {
            let min_data = [0u8; 20];
            assert!(TcpPacket::new(&min_data).is_some());
        }
    }

    /// テスト階層: TCP > パケットパース > フィールド抽出
    mod field_extraction {
        use super::*;

        #[test]
        fn ポート番号を取得できる() {
            let mut data = [0u8; 20];
            data[0..2].copy_from_slice(&8080u16.to_be_bytes());
            data[2..4].copy_from_slice(&80u16.to_be_bytes());
            
            let packet = TcpPacket::new(&data).unwrap();
            assert_eq!(packet.source_port(), 8080);
            assert_eq!(packet.destination_port(), 80);
        }

        #[test]
        fn シーケンス番号を取得できる() {
            let mut data = [0u8; 20];
            data[4..8].copy_from_slice(&12345u32.to_be_bytes());
            
            let packet = TcpPacket::new(&data).unwrap();
            assert_eq!(packet.sequence_number(), 12345);
        }

        #[test]
        fn 確認応答番号を取得できる() {
            let mut data = [0u8; 20];
            data[8..12].copy_from_slice(&67890u32.to_be_bytes());
            
            let packet = TcpPacket::new(&data).unwrap();
            assert_eq!(packet.acknowledgment_number(), 67890);
        }

        #[test]
        fn データオフセットを取得できる() {
            let mut data = [0u8; 20];
            data[12] = 5 << 4; // 5 * 4 = 20 bytes
            
            let packet = TcpPacket::new(&data).unwrap();
            assert_eq!(packet.data_offset(), 20);
        }

        #[test]
        fn フラグを取得できる() {
            let mut data = [0u8; 20];
            data[12] = 5 << 4;
            data[13] = 0x12; // SYN + ACK
            
            let packet = TcpPacket::new(&data).unwrap();
            let flags = packet.flags();
            assert!(flags.syn);
            assert!(flags.ack);
            assert!(!flags.fin);
        }

        #[test]
        fn ウィンドウサイズを取得できる() {
            let mut data = [0u8; 20];
            data[12] = 5 << 4;
            data[14..16].copy_from_slice(&65535u16.to_be_bytes());
            
            let packet = TcpPacket::new(&data).unwrap();
            assert_eq!(packet.window_size(), 65535);
        }

        #[test]
        fn ペイロードを取得できる() {
            let mut data = vec![0u8; 30];
            data[12] = 5 << 4;
            data[20..30].copy_from_slice(b"HelloWorld");
            
            let packet = TcpPacket::new(&data).unwrap();
            assert_eq!(packet.payload(), b"HelloWorld");
        }
    }

    /// テスト階層: TCP > パケットパース > 典型的なパケット
    mod typical_packets {
        use super::*;

        #[test]
        fn synパケットを認識できる() {
            let mut data = [0u8; 20];
            data[12] = 5 << 4;
            data[13] = 0x02; // SYN
            data[4..8].copy_from_slice(&1000u32.to_be_bytes());
            
            let packet = TcpPacket::new(&data).unwrap();
            assert!(packet.flags().syn);
            assert!(!packet.flags().ack);
            assert_eq!(packet.sequence_number(), 1000);
        }

        #[test]
        fn syn_ackパケットを認識できる() {
            let mut data = [0u8; 20];
            data[12] = 5 << 4;
            data[13] = 0x12; // SYN + ACK
            data[4..8].copy_from_slice(&2000u32.to_be_bytes());
            data[8..12].copy_from_slice(&1001u32.to_be_bytes());
            
            let packet = TcpPacket::new(&data).unwrap();
            assert!(packet.flags().syn);
            assert!(packet.flags().ack);
            assert_eq!(packet.sequence_number(), 2000);
            assert_eq!(packet.acknowledgment_number(), 1001);
        }

        #[test]
        fn データ転送パケットを認識できる() {
            let mut data = vec![0u8; 30];
            data[12] = 5 << 4;
            data[13] = 0x18; // PSH + ACK
            data[4..8].copy_from_slice(&3000u32.to_be_bytes());
            data[8..12].copy_from_slice(&2001u32.to_be_bytes());
            data[20..30].copy_from_slice(b"TestData!!");
            
            let packet = TcpPacket::new(&data).unwrap();
            assert!(packet.flags().psh);
            assert!(packet.flags().ack);
            assert_eq!(packet.payload().len(), 10);
        }
    }
}
```

### Step 4: TCPパケットビルダー（TDD）

```rust
/// TCPパケットを構築するビルダー
pub struct TcpPacketBuilder {
    source_port: u16,
    destination_port: u16,
    sequence_number: u32,
    acknowledgment_number: u32,
    flags: TcpFlags,
    window_size: u16,
    payload: Vec<u8>,
}

impl TcpPacketBuilder {
    pub fn new(source_port: u16, destination_port: u16) -> Self {
        TcpPacketBuilder {
            source_port,
            destination_port,
            sequence_number: 0,
            acknowledgment_number: 0,
            flags: TcpFlags::new(),
            window_size: 65535,
            payload: Vec::new(),
        }
    }

    pub fn sequence_number(mut self, seq: u32) -> Self {
        self.sequence_number = seq;
        self
    }

    pub fn acknowledgment_number(mut self, ack: u32) -> Self {
        self.acknowledgment_number = ack;
        self
    }

    pub fn flags(mut self, flags: TcpFlags) -> Self {
        self.flags = flags;
        self
    }

    pub fn window_size(mut self, window: u16) -> Self {
        self.window_size = window;
        self
    }

    pub fn payload(mut self, data: &[u8]) -> Self {
        self.payload = data.to_vec();
        self
    }

    pub fn build(self, src_ip: Ipv4Addr, dst_ip: Ipv4Addr) -> Vec<u8> {
        let header_len = 20;
        let total_len = header_len + self.payload.len();
        let mut packet = vec![0u8; total_len];

        // Source port
        packet[0..2].copy_from_slice(&self.source_port.to_be_bytes());
        
        // Destination port
        packet[2..4].copy_from_slice(&self.destination_port.to_be_bytes());
        
        // Sequence number
        packet[4..8].copy_from_slice(&self.sequence_number.to_be_bytes());
        
        // Acknowledgment number
        packet[8..12].copy_from_slice(&self.acknowledgment_number.to_be_bytes());
        
        // Data offset (5 * 4 = 20 bytes)
        packet[12] = 5 << 4;
        
        // Flags
        packet[13] = self.flags.to_byte();
        
        // Window size
        packet[14..16].copy_from_slice(&self.window_size.to_be_bytes());
        
        // Payload
        packet[20..].copy_from_slice(&self.payload);
        
        // Calculate checksum
        let checksum = calculate_tcp_checksum(&packet, src_ip, dst_ip);
        packet[16..18].copy_from_slice(&checksum.to_be_bytes());

        packet
    }
}

#[cfg(test)]
mod packet_builder_tests {
    use super::*;

    /// テスト階層: TCP > パケット構築 > 基本構築
    mod basic_construction {
        use super::*;

        #[test]
        fn ペイロードなしのパケットを構築できる() {
            let src = Ipv4Addr::new(192, 168, 1, 1);
            let dst = Ipv4Addr::new(192, 168, 1, 2);
            
            let packet = TcpPacketBuilder::new(8080, 80)
                .build(src, dst);
            
            assert_eq!(packet.len(), 20);
        }

        #[test]
        fn ペイロード付きパケットを構築できる() {
            let src = Ipv4Addr::new(10, 0, 0, 1);
            let dst = Ipv4Addr::new(10, 0, 0, 2);
            
            let packet = TcpPacketBuilder::new(12345, 80)
                .payload(b"GET / HTTP/1.1")
                .build(src, dst);
            
            assert_eq!(packet.len(), 20 + 14);
        }
    }

    /// テスト階層: TCP > パケット構築 > 典型的なパケット生成
    mod typical_packet_generation {
        use super::*;

        #[test]
        fn synパケットを構築できる() {
            let src = Ipv4Addr::new(192, 168, 1, 100);
            let dst = Ipv4Addr::new(192, 168, 1, 1);
            
            let mut flags = TcpFlags::new();
            flags.syn = true;
            
            let packet_bytes = TcpPacketBuilder::new(50000, 80)
                .sequence_number(1000)
                .flags(flags)
                .build(src, dst);
            
            let packet = TcpPacket::new(&packet_bytes).unwrap();
            assert_eq!(packet.source_port(), 50000);
            assert_eq!(packet.destination_port(), 80);
            assert_eq!(packet.sequence_number(), 1000);
            assert!(packet.flags().syn);
            assert!(!packet.flags().ack);
        }

        #[test]
        fn syn_ackパケットを構築できる() {
            let src = Ipv4Addr::new(192, 168, 1, 1);
            let dst = Ipv4Addr::new(192, 168, 1, 100);
            
            let mut flags = TcpFlags::new();
            flags.syn = true;
            flags.ack = true;
            
            let packet_bytes = TcpPacketBuilder::new(80, 50000)
                .sequence_number(2000)
                .acknowledgment_number(1001)
                .flags(flags)
                .build(src, dst);
            
            let packet = TcpPacket::new(&packet_bytes).unwrap();
            assert!(packet.flags().syn);
            assert!(packet.flags().ack);
            assert_eq!(packet.acknowledgment_number(), 1001);
        }

        #[test]
        fn データ転送パケットを構築できる() {
            let src = Ipv4Addr::new(10, 0, 0, 1);
            let dst = Ipv4Addr::new(10, 0, 0, 2);
            
            let mut flags = TcpFlags::new();
            flags.psh = true;
            flags.ack = true;
            
            let packet_bytes = TcpPacketBuilder::new(8080, 9090)
                .sequence_number(5000)
                .acknowledgment_number(6000)
                .flags(flags)
                .payload(b"Hello, TCP!")
                .build(src, dst);
            
            let packet = TcpPacket::new(&packet_bytes).unwrap();
            assert!(packet.flags().psh);
            assert!(packet.flags().ack);
            assert_eq!(packet.payload(), b"Hello, TCP!");
        }
    }

    /// テスト階層: TCP > パケット構築 > 正確性検証
    mod correctness {
        use super::*;

        #[test]
        fn 構築したパケットのチェックサムは正しい() {
            let src = Ipv4Addr::new(172, 16, 0, 1);
            let dst = Ipv4Addr::new(172, 16, 0, 2);
            
            let packet_bytes = TcpPacketBuilder::new(12345, 80)
                .sequence_number(1000)
                .build(src, dst);
            
            let packet = TcpPacket::new(&packet_bytes).unwrap();
            assert!(packet.verify_checksum(src, dst));
        }

        #[test]
        fn パース_ビルド_パースの往復で同じになる() {
            let src = Ipv4Addr::new(10, 20, 30, 40);
            let dst = Ipv4Addr::new(50, 60, 70, 80);
            
            let original = TcpPacketBuilder::new(8080, 80)
                .sequence_number(12345)
                .acknowledgment_number(67890)
                .payload(b"Round trip")
                .build(src, dst);
            
            let parsed = TcpPacket::new(&original).unwrap();
            
            let rebuilt = TcpPacketBuilder::new(
                parsed.source_port(),
                parsed.destination_port()
            )
            .sequence_number(parsed.sequence_number())
            .acknowledgment_number(parsed.acknowledgment_number())
            .flags(parsed.flags())
            .window_size(parsed.window_size())
            .payload(parsed.payload())
            .build(src, dst);
            
            assert_eq!(original, rebuilt);
        }
    }
}
```

## 統合テスト: スタック全体のテスト

### tests/integration_test.rs

```rust
use rust_tcp_tdd::ethernet::{EthernetFrame, EthernetFrameBuilder, MacAddress, EtherType};
use rust_tcp_tdd::ipv4::{Ipv4Packet, Ipv4PacketBuilder, IpProtocol};
use rust_tcp_tdd::tcp::{TcpPacket, TcpPacketBuilder, TcpFlags};
use std::net::Ipv4Addr;

/// テスト階層: 統合 > スタック全体 > レイヤー連携
mod stack_integration {
    use super::*;

    #[test]
    fn ethernet_ipv4_tcpの完全なパケットを構築しパースできる() {
        // アドレス設定
        let src_mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
        let dst_mac = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
        let src_ip = Ipv4Addr::new(192, 168, 1, 100);
        let dst_ip = Ipv4Addr::new(192, 168, 1, 1);

        // TCPパケット構築
        let mut tcp_flags = TcpFlags::new();
        tcp_flags.syn = true;
        
        let tcp_packet = TcpPacketBuilder::new(50000, 80)
            .sequence_number(1000)
            .flags(tcp_flags)
            .build(src_ip, dst_ip);

        // IPv4パケット構築
        let ip_packet = Ipv4PacketBuilder::new(src_ip, dst_ip, IpProtocol::Tcp)
            .payload(&tcp_packet)
            .build();

        // Ethernetフレーム構築
        let frame_bytes = EthernetFrameBuilder::new(dst_mac, src_mac, EtherType::Ipv4)
            .payload(&ip_packet)
            .build();

        // === パース処理 ===

        // Ethernetフレームパース
        let eth_frame = EthernetFrame::new(&frame_bytes).unwrap();
        assert_eq!(eth_frame.source(), src_mac);
        assert_eq!(eth_frame.destination(), dst_mac);
        assert_eq!(eth_frame.ether_type(), EtherType::Ipv4);

        // IPv4パケットパース
        let ip_pkt = Ipv4Packet::new(eth_frame.payload()).unwrap();
        assert_eq!(ip_pkt.source(), src_ip);
        assert_eq!(ip_pkt.destination(), dst_ip);
        assert_eq!(ip_pkt.protocol(), IpProtocol::Tcp);
        assert!(ip_pkt.verify_checksum());

        // TCPパケットパース
        let tcp_pkt = TcpPacket::new(ip_pkt.payload()).unwrap();
        assert_eq!(tcp_pkt.source_port(), 50000);
        assert_eq!(tcp_pkt.destination_port(), 80);
        assert!(tcp_pkt.flags().syn);
        assert!(tcp_pkt.verify_checksum(src_ip, dst_ip));
    }

    #[test]
    fn tcp_3way_handshakeシーケンスをシミュレートできる() {
        let client_mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
        let server_mac = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
        let client_ip = Ipv4Addr::new(192, 168, 1, 100);
        let server_ip = Ipv4Addr::new(192, 168, 1, 1);

        // Step 1: SYN
        let mut syn_flags = TcpFlags::new();
        syn_flags.syn = true;
        
        let syn_tcp = TcpPacketBuilder::new(50000, 80)
            .sequence_number(1000)
            .flags(syn_flags)
            .build(client_ip, server_ip);
        
        let syn_packet = TcpPacket::new(&syn_tcp).unwrap();
        assert!(syn_packet.flags().syn);
        assert!(!syn_packet.flags().ack);

        // Step 2: SYN-ACK
        let mut syn_ack_flags = TcpFlags::new();
        syn_ack_flags.syn = true;
        syn_ack_flags.ack = true;
        
        let syn_ack_tcp = TcpPacketBuilder::new(80, 50000)
            .sequence_number(2000)
            .acknowledgment_number(1001)
            .flags(syn_ack_flags)
            .build(server_ip, client_ip);
        
        let syn_ack_packet = TcpPacket::new(&syn_ack_tcp).unwrap();
        assert!(syn_ack_packet.flags().syn);
        assert!(syn_ack_packet.flags().ack);
        assert_eq!(syn_ack_packet.acknowledgment_number(), 1001);

        // Step 3: ACK
        let mut ack_flags = TcpFlags::new();
        ack_flags.ack = true;
        
        let ack_tcp = TcpPacketBuilder::new(50000, 80)
            .sequence_number(1001)
            .acknowledgment_number(2001)
            .flags(ack_flags)
            .build(client_ip, server_ip);
        
        let ack_packet = TcpPacket::new(&ack_tcp).unwrap();
        assert!(!ack_packet.flags().syn);
        assert!(ack_packet.flags().ack);
        assert_eq!(ack_packet.sequence_number(), 1001);
        assert_eq!(ack_packet.acknowledgment_number(), 2001);
    }

    #[test]
    fn データ転送とエコーバックをシミュレートできる() {
        let client_ip = Ipv4Addr::new(192, 168, 1, 100);
        let server_ip = Ipv4Addr::new(192, 168, 1, 1);

        // クライアント → サーバー: データ送信
        let mut psh_ack_flags = TcpFlags::new();
        psh_ack_flags.psh = true;
        psh_ack_flags.ack = true;
        
        let data = b"Hello, Server!";
        let request_tcp = TcpPacketBuilder::new(50000, 80)
            .sequence_number(1001)
            .acknowledgment_number(2001)
            .flags(psh_ack_flags)
            .payload(data)
            .build(client_ip, server_ip);
        
        let request = TcpPacket::new(&request_tcp).unwrap();
        assert_eq!(request.payload(), data);

        // サーバー → クライアント: エコーバック
        let echo_tcp = TcpPacketBuilder::new(80, 50000)
            .sequence_number(2001)
            .acknowledgment_number(1001 + data.len() as u32)
            .flags(psh_ack_flags)
            .payload(data) // エコー
            .build(server_ip, client_ip);
        
        let echo = TcpPacket::new(&echo_tcp).unwrap();
        assert_eq!(echo.payload(), data);
        assert_eq!(echo.acknowledgment_number(), 1001 + 14);
    }
}
```

## テスト実行とレポート

### すべてのテストを実行

```bash
# 全テスト実行
cargo test

# 詳細表示
cargo test -- --nocapture

# 特定のモジュールのみ
cargo test ethernet
cargo test ipv4
cargo test tcp
cargo test integration
```

### テストの階層構造を確認

```bash
cargo test -- --list
```

出力例：

```text
ethernet::tests::mac_address::新しいmacアドレスを作成できる
ethernet::tests::mac_address::macアドレスを文字列表示できる
ethernet::tests::mac_address::ブロードキャストアドレスを作成できる
...
ipv4::protocol_tests::conversion::tcpプロトコルに変換できる
...
tcp::flag_tests::typical_patterns::synパケットのフラグ
tcp::flag_tests::typical_patterns::syn_ackパケットのフラグ
...
stack_integration::tcp_3way_handshakeシーケンスをシミュレートできる
```

## まとめ: テストが語る仕様

このハンズオンでは、**テストコードそのものがドキュメント**として機能するように設計しました：

### テスト階層の意図

```text
Ethernet/
├─ MACアドレス/
│  ├─ 基本操作       ← 型の基本的な使い方
│  └─ 等価性判定     ← 比較の振る舞い
├─ フレームパース/
│  ├─ バリデーション ← どんな入力が有効・無効か
│  ├─ フィールド抽出 ← 各フィールドの取得方法
│  └─ 実際のパケット例 ← 現実的な使用例
└─ フレーム構築/
   ├─ 基本構築       ← ビルダーの使い方
   └─ 正確性検証     ← パース↔ビルドの整合性
```

### TDDのメリットを実感できたか？

1. **小さいサイクルで進める安心感**
   - 一つずつテストを書いて、確実に動くコードを積み上げる

2. **リファクタリングの自信**
   - テストがあるから、コードをきれいにする際も壊れていないことを確認できる

3. **テストが仕様書になる**
   - 後から参加した人がテストを読めば、APIの使い方が分かる

4. **設計へのフィードバック**
   - テストを書くことで「使いにくいAPI」に気づける

## 次のステップ

このTDDハンズオンを完了したら：

1. **TUN/TAPデバイスの実装をTDDで追加**
2. **TCP状態機械の実装をTDDで追加**
3. **実際のエコーサーバーをTDDで実装**
4. **エラーケースのテストを充実させる**

## 参考資料

- Kent Beck『テスト駆動開発』（オーム社）
- t-wada『テスト駆動開発の定義』
- 『Software Design 2022年3月号』TDD特集
