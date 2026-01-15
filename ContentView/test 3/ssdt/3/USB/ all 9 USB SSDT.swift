// ============================================================================
// USB SSDT Configuration - All Port Variations (5 to 30 ports)
// ============================================================================

// MARK: - 1. 5 USB Ports (HS01-HS05)
DefinitionBlock ("", "SSDT", 2, "SYSM ", "XHC5", 0x00001000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)

    Scope (\_SB.PC00.XHCI)
    {
        Scope (RHUB)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (Zero)
                }
                Else
                {
                    Return (0x0F)
                }
            }
        }

        Device (XHUB)
        {
            Name (_ADR, Zero)
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }

            // 5 USB Ports
            Device (HS01) { Name (_ADR, One) }
            Device (HS02) { Name (_ADR, 0x02) }
            Device (HS03) { Name (_ADR, 0x03) }
            Device (HS04) { Name (_ADR, 0x04) }
            Device (HS05) { Name (_ADR, 0x05) }
        }
    }
}

// MARK: - 2. 7 USB Ports (HS01-HS07)
DefinitionBlock ("", "SSDT", 2, "SYSM ", "XHC7", 0x00001000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)

    Scope (\_SB.PC00.XHCI)
    {
        Scope (RHUB)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (Zero)
                }
                Else
                {
                    Return (0x0F)
                }
            }
        }

        Device (XHUB)
        {
            Name (_ADR, Zero)
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }

            // 7 USB Ports
            Device (HS01) { Name (_ADR, One) }
            Device (HS02) { Name (_ADR, 0x02) }
            Device (HS03) { Name (_ADR, 0x03) }
            Device (HS04) { Name (_ADR, 0x04) }
            Device (HS05) { Name (_ADR, 0x05) }
            Device (HS06) { Name (_ADR, 0x06) }
            Device (HS07) { Name (_ADR, 0x07) }
        }
    }
}

// MARK: - 3. 9 USB Ports (HS01-HS09)
DefinitionBlock ("", "SSDT", 2, "SYSM ", "XHC9", 0x00001000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)

    Scope (\_SB.PC00.XHCI)
    {
        Scope (RHUB)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (Zero)
                }
                Else
                {
                    Return (0x0F)
                }
            }
        }

        Device (XHUB)
        {
            Name (_ADR, Zero)
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }

            // 9 USB Ports
            Device (HS01) { Name (_ADR, One) }
            Device (HS02) { Name (_ADR, 0x02) }
            Device (HS03) { Name (_ADR, 0x03) }
            Device (HS04) { Name (_ADR, 0x04) }
            Device (HS05) { Name (_ADR, 0x05) }
            Device (HS06) { Name (_ADR, 0x06) }
            Device (HS07) { Name (_ADR, 0x07) }
            Device (HS08) { Name (_ADR, 0x08) }
            Device (HS09) { Name (_ADR, 0x09) }
        }
    }
}

// MARK: - 4. 11 USB Ports (HS01-HS11)
DefinitionBlock ("", "SSDT", 2, "SYSM ", "XHC11", 0x00001000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)

    Scope (\_SB.PC00.XHCI)
    {
        Scope (RHUB)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (Zero)
                }
                Else
                {
                    Return (0x0F)
                }
            }
        }

        Device (XHUB)
        {
            Name (_ADR, Zero)
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }

            // 11 USB Ports
            Device (HS01) { Name (_ADR, One) }
            Device (HS02) { Name (_ADR, 0x02) }
            Device (HS03) { Name (_ADR, 0x03) }
            Device (HS04) { Name (_ADR, 0x04) }
            Device (HS05) { Name (_ADR, 0x05) }
            Device (HS06) { Name (_ADR, 0x06) }
            Device (HS07) { Name (_ADR, 0x07) }
            Device (HS08) { Name (_ADR, 0x08) }
            Device (HS09) { Name (_ADR, 0x09) }
            Device (HS10) { Name (_ADR, 0x0A) }
            Device (HS11) { Name (_ADR, 0x0B) }
        }
    }
}

// MARK: - 5. 13 USB Ports (HS01-HS13)
DefinitionBlock ("", "SSDT", 2, "SYSM ", "XHC13", 0x00001000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)

    Scope (\_SB.PC00.XHCI)
    {
        Scope (RHUB)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (Zero)
                }
                Else
                {
                    Return (0x0F)
                }
            }
        }

        Device (XHUB)
        {
            Name (_ADR, Zero)
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }

            // 13 USB Ports
            Device (HS01) { Name (_ADR, One) }
            Device (HS02) { Name (_ADR, 0x02) }
            Device (HS03) { Name (_ADR, 0x03) }
            Device (HS04) { Name (_ADR, 0x04) }
            Device (HS05) { Name (_ADR, 0x05) }
            Device (HS06) { Name (_ADR, 0x06) }
            Device (HS07) { Name (_ADR, 0x07) }
            Device (HS08) { Name (_ADR, 0x08) }
            Device (HS09) { Name (_ADR, 0x09) }
            Device (HS10) { Name (_ADR, 0x0A) }
            Device (HS11) { Name (_ADR, 0x0B) }
            Device (HS12) { Name (_ADR, 0x0C) }
            Device (HS13) { Name (_ADR, 0x0D) }
        }
    }
}

// MARK: - 6. 15 USB Ports (HS01-HS15)
DefinitionBlock ("", "SSDT", 2, "SYSM ", "XHC15", 0x00001000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)

    Scope (\_SB.PC00.XHCI)
    {
        Scope (RHUB)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (Zero)
                }
                Else
                {
                    Return (0x0F)
                }
            }
        }

        Device (XHUB)
        {
            Name (_ADR, Zero)
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }

            // 15 USB Ports
            Device (HS01) { Name (_ADR, One) }
            Device (HS02) { Name (_ADR, 0x02) }
            Device (HS03) { Name (_ADR, 0x03) }
            Device (HS04) { Name (_ADR, 0x04) }
            Device (HS05) { Name (_ADR, 0x05) }
            Device (HS06) { Name (_ADR, 0x06) }
            Device (HS07) { Name (_ADR, 0x07) }
            Device (HS08) { Name (_ADR, 0x08) }
            Device (HS09) { Name (_ADR, 0x09) }
            Device (HS10) { Name (_ADR, 0x0A) }
            Device (HS11) { Name (_ADR, 0x0B) }
            Device (HS12) { Name (_ADR, 0x0C) }
            Device (HS13) { Name (_ADR, 0x0D) }
            Device (HS14) { Name (_ADR, 0x0E) }
            Device (HS15) { Name (_ADR, 0x0F) }
        }
    }
}

// MARK: - 7. 20 USB Ports (HS01-HS20)
DefinitionBlock ("", "SSDT", 2, "SYSM ", "XHC20", 0x00001000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)

    Scope (\_SB.PC00.XHCI)
    {
        Scope (RHUB)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (Zero)
                }
                Else
                {
                    Return (0x0F)
                }
            }
        }

        Device (XHUB)
        {
            Name (_ADR, Zero)
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }

            // 20 USB Ports
            Device (HS01) { Name (_ADR, One) }
            Device (HS02) { Name (_ADR, 0x02) }
            Device (HS03) { Name (_ADR, 0x03) }
            Device (HS04) { Name (_ADR, 0x04) }
            Device (HS05) { Name (_ADR, 0x05) }
            Device (HS06) { Name (_ADR, 0x06) }
            Device (HS07) { Name (_ADR, 0x07) }
            Device (HS08) { Name (_ADR, 0x08) }
            Device (HS09) { Name (_ADR, 0x09) }
            Device (HS10) { Name (_ADR, 0x0A) }
            Device (HS11) { Name (_ADR, 0x0B) }
            Device (HS12) { Name (_ADR, 0x0C) }
            Device (HS13) { Name (_ADR, 0x0D) }
            Device (HS14) { Name (_ADR, 0x0E) }
            Device (HS15) { Name (_ADR, 0x0F) }
            Device (HS16) { Name (_ADR, 0x10) }
            Device (HS17) { Name (_ADR, 0x11) }
            Device (HS18) { Name (_ADR, 0x12) }
            Device (HS19) { Name (_ADR, 0x13) }
            Device (HS20) { Name (_ADR, 0x14) }
        }
    }
}

// MARK: - 8. 25 USB Ports (HS01-HS25)
DefinitionBlock ("", "SSDT", 2, "SYSM ", "XHC25", 0x00001000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)

    Scope (\_SB.PC00.XHCI)
    {
        Scope (RHUB)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (Zero)
                }
                Else
                {
                    Return (0x0F)
                }
            }
        }

        Device (XHUB)
        {
            Name (_ADR, Zero)
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }

            // 25 USB Ports
            Device (HS01) { Name (_ADR, One) }
            Device (HS02) { Name (_ADR, 0x02) }
            Device (HS03) { Name (_ADR, 0x03) }
            Device (HS04) { Name (_ADR, 0x04) }
            Device (HS05) { Name (_ADR, 0x05) }
            Device (HS06) { Name (_ADR, 0x06) }
            Device (HS07) { Name (_ADR, 0x07) }
            Device (HS08) { Name (_ADR, 0x08) }
            Device (HS09) { Name (_ADR, 0x09) }
            Device (HS10) { Name (_ADR, 0x0A) }
            Device (HS11) { Name (_ADR, 0x0B) }
            Device (HS12) { Name (_ADR, 0x0C) }
            Device (HS13) { Name (_ADR, 0x0D) }
            Device (HS14) { Name (_ADR, 0x0E) }
            Device (HS15) { Name (_ADR, 0x0F) }
            Device (HS16) { Name (_ADR, 0x10) }
            Device (HS17) { Name (_ADR, 0x11) }
            Device (HS18) { Name (_ADR, 0x12) }
            Device (HS19) { Name (_ADR, 0x13) }
            Device (HS20) { Name (_ADR, 0x14) }
            Device (HS21) { Name (_ADR, 0x15) }
            Device (HS22) { Name (_ADR, 0x16) }
            Device (HS23) { Name (_ADR, 0x17) }
            Device (HS24) { Name (_ADR, 0x18) }
            Device (HS25) { Name (_ADR, 0x19) }
        }
    }
}

// MARK: - 9. 30 USB Ports (HS01-HS30)
DefinitionBlock ("", "SSDT", 2, "SYSM ", "XHC30", 0x00001000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)

    Scope (\_SB.PC00.XHCI)
    {
        Scope (RHUB)
        {
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (Zero)
                }
                Else
                {
                    Return (0x0F)
                }
            }
        }

        Device (XHUB)
        {
            Name (_ADR, Zero)
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }

            // 30 USB Ports
            Device (HS01) { Name (_ADR, One) }
            Device (HS02) { Name (_ADR, 0x02) }
            Device (HS03) { Name (_ADR, 0x03) }
            Device (HS04) { Name (_ADR, 0x04) }
            Device (HS05) { Name (_ADR, 0x05) }
            Device (HS06) { Name (_ADR, 0x06) }
            Device (HS07) { Name (_ADR, 0x07) }
            Device (HS08) { Name (_ADR, 0x08) }
            Device (HS09) { Name (_ADR, 0x09) }
            Device (HS10) { Name (_ADR, 0x0A) }
            Device (HS11) { Name (_ADR, 0x0B) }
            Device (HS12) { Name (_ADR, 0x0C) }
            Device (HS13) { Name (_ADR, 0x0D) }
            Device (HS14) { Name (_ADR, 0x0E) }
            Device (HS15) { Name (_ADR, 0x0F) }
            Device (HS16) { Name (_ADR, 0x10) }
            Device (HS17) { Name (_ADR, 0x11) }
            Device (HS18) { Name (_ADR, 0x12) }
            Device (HS19) { Name (_ADR, 0x13) }
            Device (HS20) { Name (_ADR, 0x14) }
            Device (HS21) { Name (_ADR, 0x15) }
            Device (HS22) { Name (_ADR, 0x16) }
            Device (HS23) { Name (_ADR, 0x17) }
            Device (HS24) { Name (_ADR, 0x18) }
            Device (HS25) { Name (_ADR, 0x19) }
            Device (HS26) { Name (_ADR, 0x1A) }
            Device (HS27) { Name (_ADR, 0x1B) }
            Device (HS28) { Name (_ADR, 0x1C) }
            Device (HS29) { Name (_ADR, 0x1D) }
            Device (HS30) { Name (_ADR, 0x1E) }
        }
    }
}

// ============================================================================
// END OF USB SSDT COLLECTION
// ============================================================================