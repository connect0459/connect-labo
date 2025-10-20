use std::net::Ipv4Addr;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ipv4パケットは20バイト未満を拒否する() {
        let short_data = [0u8; 19];
        assert!(Ipv4Packet::new(&short_data).is_none());
    }
}
