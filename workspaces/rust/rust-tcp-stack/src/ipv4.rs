use std::net::Ipv4Addr;

pub struct Ipv4Packet<'a> {
    data: &'a [u8],
}

impl<'a> Ipv4Packet<'a> {
    pub fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 20 {
            return None;
        }
        Some(Ipv4Packet { data })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ipv4パケットは20バイト未満を拒否する() {
        let short_data = [0u8; 19];
        assert!(Ipv4Packet::new(&short_data).is_none());
    }
}
