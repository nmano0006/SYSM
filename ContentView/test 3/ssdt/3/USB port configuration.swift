// ============================================================================
// USB SSDT Configuration - Complete Port Management (5 to 30 ports)
// ============================================================================

// MARK: - USB Power Properties (Required for all USB configurations)
DefinitionBlock ("", "SSDT", 2, "SYSM", "USBX", 0x00000000)
{
    External (_SB_.PC00, DeviceObj)
    
    Scope (\_SB.PC00)
    {
        Device (USBX)
        {
            Name (_HID, "XHCPWR")
            Method (_STA, 0, NotSerialized)
            {
                Return (0x0F)
            }
            
            Name (_DSD, Package (0x02)
            {
                ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
                Package (0x04)
                {
                    "usb2-port-power-off", 
                    Package (0x02)
                    {
                        0x00, 
                        0x00
                    }, 
                    "usb2-port-power-on", 
                    Package (0x02)
                    {
                        0x01, 
                        0x01
                    }, 
                    "usb3-port-power-off", 
                    Package (0x02)
                    {
                        0x00, 
                        0x00
                    }, 
                    "usb3-port-power-on", 
                    Package (0x02)
                    {
                        0x01, 
                        0x01
                    }
                }
            })
        }
    }
}

// MARK: - 1. 5 USB Ports Configuration (HS01-HS05, SS01-SS05)
DefinitionBlock ("", "SSDT", 2, "SYSM", "XHC5", 0x00000000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)
    External (DTGP, MethodObj)

    Scope (\_SB.PC00.XHCI)
    {
        // Disable RHUB in macOS
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

        // Create our own hub with proper port configuration
        Device (XHC)
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

            // USB 2.0 Ports (HSxx)
            Device (HS01)
            {
                Name (_ADR, One)
                Name (_UPC, Package (0x04) { 0xFF, 0x00, Zero, Zero }) // UsbConnector, Port, Hidden, TypeC
                Name (_PLD, Package (0x01)
                {
                    Buffer (0x10)
                    {
                        /* 0000 */  0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                        /* 0008 */  0x30, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    }
                })
            }
            
            Device (HS02)
            {
                Name (_ADR, 0x02)
                Name (_UPC, Package (0x04) { 0xFF, 0x00, Zero, Zero })
            }
            
            Device (HS03)
            {
                Name (_ADR, 0x03)
                Name (_UPC, Package (0x04) { 0xFF, 0x00, Zero, Zero })
            }
            
            Device (HS04)
            {
                Name (_ADR, 0x04)
                Name (_UPC, Package (0x04) { 0xFF, 0x00, Zero, Zero })
            }
            
            Device (HS05)
            {
                Name (_ADR, 0x05)
                Name (_UPC, Package (0x04) { 0xFF, 0x00, Zero, Zero })
            }

            // USB 3.0+ Ports (SSxx)
            Device (SS01)
            {
                Name (_ADR, 0x11)
                Name (_UPC, Package (0x04) { 0xFF, 0x03, Zero, Zero }) // Type A USB 3.0
            }
            
            Device (SS02)
            {
                Name (_ADR, 0x12)
                Name (_UPC, Package (0x04) { 0xFF, 0x03, Zero, Zero })
            }
            
            Device (SS03)
            {
                Name (_ADR, 0x13)
                Name (_UPC, Package (0x04) { 0xFF, 0x03, Zero, Zero })
            }
            
            Device (SS04)
            {
                Name (_ADR, 0x14)
                Name (_UPC, Package (0x04) { 0xFF, 0x03, Zero, Zero })
            }
            
            Device (SS05)
            {
                Name (_ADR, 0x15)
                Name (_UPC, Package (0x04) { 0xFF, 0x03, Zero, Zero })
            }
        }
        
        // XHCI Properties
        Method (_DSM, 4, NotSerialized)
        {
            Store (Package (0x18)
            {
                "AAPL,current-available", 
                0x0834, 
                "AAPL,current-extra", 
                0x0A8C, 
                "AAPL,current-in-sleep", 
                0x0A8C, 
                "AAPL,max-port-current-in-sleep", 
                0x0834, 
                "AAPL,device-internal", 
                Zero, 
                "AAPL,clock-id", 
                Buffer (One) { 0x01 }, 
                "AAPL,root-hub-depth", 
                0x14, 
                "AAPL,XHC-clock-id", 
                One, 
                "model", 
                Buffer () { "XHCI Controller - 5 Ports" }, 
                "name", 
                Buffer () { "XHCI" }, 
                "AAPL,slot-name", 
                Buffer () { "Built In" }, 
                "device_type", 
                Buffer () { "USB Controller" }, 
                "built-in", 
                Buffer (One) { 0x01 }
            }, Local0)
            
            DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
            Return (Local0)
        }
    }
}

// MARK: - 2. 7 USB Ports Configuration (HS01-HS07, SS01-SS07)
DefinitionBlock ("", "SSDT", 2, "SYSM", "XHC7", 0x00000000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)
    External (DTGP, MethodObj)

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

        Device (XHC)
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

            // USB 2.0 Ports
            Device (HS01) { Name (_ADR, One) }
            Device (HS02) { Name (_ADR, 0x02) }
            Device (HS03) { Name (_ADR, 0x03) }
            Device (HS04) { Name (_ADR, 0x04) }
            Device (HS05) { Name (_ADR, 0x05) }
            Device (HS06) { Name (_ADR, 0x06) }
            Device (HS07) { Name (_ADR, 0x07) }

            // USB 3.0+ Ports
            Device (SS01) { Name (_ADR, 0x11) }
            Device (SS02) { Name (_ADR, 0x12) }
            Device (SS03) { Name (_ADR, 0x13) }
            Device (SS04) { Name (_ADR, 0x14) }
            Device (SS05) { Name (_ADR, 0x15) }
            Device (SS06) { Name (_ADR, 0x16) }
            Device (SS07) { Name (_ADR, 0x17) }
        }
        
        Method (_DSM, 4, NotSerialized)
        {
            Store (Package (0x18)
            {
                "AAPL,current-available", 
                0x0834, 
                "AAPL,current-extra", 
                0x0A8C, 
                "AAPL,current-in-sleep", 
                0x0A8C, 
                "AAPL,max-port-current-in-sleep", 
                0x0834, 
                "AAPL,device-internal", 
                Zero, 
                "AAPL,clock-id", 
                Buffer (One) { 0x01 }, 
                "AAPL,root-hub-depth", 
                0x16, 
                "AAPL,XHC-clock-id", 
                One, 
                "model", 
                Buffer () { "XHCI Controller - 7 Ports" }, 
                "name", 
                Buffer () { "XHCI" }, 
                "AAPL,slot-name", 
                Buffer () { "Built In" }, 
                "device_type", 
                Buffer () { "USB Controller" }, 
                "built-in", 
                Buffer (One) { 0x01 }
            }, Local0)
            
            DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
            Return (Local0)
        }
    }
}

// MARK: - 3. 9 USB Ports Configuration (HS01-HS09, SS01-SS09)
DefinitionBlock ("", "SSDT", 2, "SYSM", "XHC9", 0x00000000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)
    External (DTGP, MethodObj)

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

        Device (XHC)
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

            // USB 2.0 Ports
            Device (HS01) { Name (_ADR, One) }
            Device (HS02) { Name (_ADR, 0x02) }
            Device (HS03) { Name (_ADR, 0x03) }
            Device (HS04) { Name (_ADR, 0x04) }
            Device (HS05) { Name (_ADR, 0x05) }
            Device (HS06) { Name (_ADR, 0x06) }
            Device (HS07) { Name (_ADR, 0x07) }
            Device (HS08) { Name (_ADR, 0x08) }
            Device (HS09) { Name (_ADR, 0x09) }

            // USB 3.0+ Ports
            Device (SS01) { Name (_ADR, 0x11) }
            Device (SS02) { Name (_ADR, 0x12) }
            Device (SS03) { Name (_ADR, 0x13) }
            Device (SS04) { Name (_ADR, 0x14) }
            Device (SS05) { Name (_ADR, 0x15) }
            Device (SS06) { Name (_ADR, 0x16) }
            Device (SS07) { Name (_ADR, 0x17) }
            Device (SS08) { Name (_ADR, 0x18) }
            Device (SS09) { Name (_ADR, 0x19) }
        }
        
        Method (_DSM, 4, NotSerialized)
        {
            Store (Package (0x18)
            {
                "AAPL,current-available", 
                0x0834, 
                "AAPL,current-extra", 
                0x0A8C, 
                "AAPL,current-in-sleep", 
                0x0A8C, 
                "AAPL,max-port-current-in-sleep", 
                0x0834, 
                "AAPL,device-internal", 
                Zero, 
                "AAPL,clock-id", 
                Buffer (One) { 0x01 }, 
                "AAPL,root-hub-depth", 
                0x18, 
                "AAPL,XHC-clock-id", 
                One, 
                "model", 
                Buffer () { "XHCI Controller - 9 Ports" }, 
                "name", 
                Buffer () { "XHCI" }, 
                "AAPL,slot-name", 
                Buffer () { "Built In" }, 
                "device_type", 
                Buffer () { "USB Controller" }, 
                "built-in", 
                Buffer (One) { 0x01 }
            }, Local0)
            
            DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
            Return (Local0)
        }
    }
}

// MARK: - 4. 11 USB Ports Configuration (HS01-HS11, SS01-SS11)
DefinitionBlock ("", "SSDT", 2, "SYSM", "XHC11", 0x00000000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)
    External (DTGP, MethodObj)

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

        Device (XHC)
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

            // USB 2.0 Ports
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

            // USB 3.0+ Ports
            Device (SS01) { Name (_ADR, 0x11) }
            Device (SS02) { Name (_ADR, 0x12) }
            Device (SS03) { Name (_ADR, 0x13) }
            Device (SS04) { Name (_ADR, 0x14) }
            Device (SS05) { Name (_ADR, 0x15) }
            Device (SS06) { Name (_ADR, 0x16) }
            Device (SS07) { Name (_ADR, 0x17) }
            Device (SS08) { Name (_ADR, 0x18) }
            Device (SS09) { Name (_ADR, 0x19) }
            Device (SS10) { Name (_ADR, 0x1A) }
            Device (SS11) { Name (_ADR, 0x1B) }
        }
        
        Method (_DSM, 4, NotSerialized)
        {
            Store (Package (0x18)
            {
                "AAPL,current-available", 
                0x0834, 
                "AAPL,current-extra", 
                0x0A8C, 
                "AAPL,current-in-sleep", 
                0x0A8C, 
                "AAPL,max-port-current-in-sleep", 
                0x0834, 
                "AAPL,device-internal", 
                Zero, 
                "AAPL,clock-id", 
                Buffer (One) { 0x01 }, 
                "AAPL,root-hub-depth", 
                0x1A, 
                "AAPL,XHC-clock-id", 
                One, 
                "model", 
                Buffer () { "XHCI Controller - 11 Ports" }, 
                "name", 
                Buffer () { "XHCI" }, 
                "AAPL,slot-name", 
                Buffer () { "Built In" }, 
                "device_type", 
                Buffer () { "USB Controller" }, 
                "built-in", 
                Buffer (One) { 0x01 }
            }, Local0)
            
            DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
            Return (Local0)
        }
    }
}

// MARK: - 5. 13 USB Ports Configuration (HS01-HS13, SS01-SS13)
DefinitionBlock ("", "SSDT", 2, "SYSM", "XHC13", 0x00000000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)
    External (DTGP, MethodObj)

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

        Device (XHC)
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

            // USB 2.0 Ports
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

            // USB 3.0+ Ports
            Device (SS01) { Name (_ADR, 0x11) }
            Device (SS02) { Name (_ADR, 0x12) }
            Device (SS03) { Name (_ADR, 0x13) }
            Device (SS04) { Name (_ADR, 0x14) }
            Device (SS05) { Name (_ADR, 0x15) }
            Device (SS06) { Name (_ADR, 0x16) }
            Device (SS07) { Name (_ADR, 0x17) }
            Device (SS08) { Name (_ADR, 0x18) }
            Device (SS09) { Name (_ADR, 0x19) }
            Device (SS10) { Name (_ADR, 0x1A) }
            Device (SS11) { Name (_ADR, 0x1B) }
            Device (SS12) { Name (_ADR, 0x1C) }
            Device (SS13) { Name (_ADR, 0x1D) }
        }
        
        Method (_DSM, 4, NotSerialized)
        {
            Store (Package (0x18)
            {
                "AAPL,current-available", 
                0x0834, 
                "AAPL,current-extra", 
                0x0A8C, 
                "AAPL,current-in-sleep", 
                0x0A8C, 
                "AAPL,max-port-current-in-sleep", 
                0x0834, 
                "AAPL,device-internal", 
                Zero, 
                "AAPL,clock-id", 
                Buffer (One) { 0x01 }, 
                "AAPL,root-hub-depth", 
                0x1C, 
                "AAPL,XHC-clock-id", 
                One, 
                "model", 
                Buffer () { "XHCI Controller - 13 Ports" }, 
                "name", 
                Buffer () { "XHCI" }, 
                "AAPL,slot-name", 
                Buffer () { "Built In" }, 
                "device_type", 
                Buffer () { "USB Controller" }, 
                "built-in", 
                Buffer (One) { 0x01 }
            }, Local0)
            
            DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
            Return (Local0)
        }
    }
}

// MARK: - 6. 15 USB Ports Configuration (HS01-HS15, SS01-SS15)
DefinitionBlock ("", "SSDT", 2, "SYSM", "XHC15", 0x00000000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)
    External (DTGP, MethodObj)

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

        Device (XHC)
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

            // USB 2.0 Ports
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

            // USB 3.0+ Ports
            Device (SS01) { Name (_ADR, 0x11) }
            Device (SS02) { Name (_ADR, 0x12) }
            Device (SS03) { Name (_ADR, 0x13) }
            Device (SS04) { Name (_ADR, 0x14) }
            Device (SS05) { Name (_ADR, 0x15) }
            Device (SS06) { Name (_ADR, 0x16) }
            Device (SS07) { Name (_ADR, 0x17) }
            Device (SS08) { Name (_ADR, 0x18) }
            Device (SS09) { Name (_ADR, 0x19) }
            Device (SS10) { Name (_ADR, 0x1A) }
            Device (SS11) { Name (_ADR, 0x1B) }
            Device (SS12) { Name (_ADR, 0x1C) }
            Device (SS13) { Name (_ADR, 0x1D) }
            Device (SS14) { Name (_ADR, 0x1E) }
            Device (SS15) { Name (_ADR, 0x1F) }
        }
        
        Method (_DSM, 4, NotSerialized)
        {
            Store (Package (0x18)
            {
                "AAPL,current-available", 
                0x0834, 
                "AAPL,current-extra", 
                0x0A8C, 
                "AAPL,current-in-sleep", 
                0x0A8C, 
                "AAPL,max-port-current-in-sleep", 
                0x0834, 
                "AAPL,device-internal", 
                Zero, 
                "AAPL,clock-id", 
                Buffer (One) { 0x01 }, 
                "AAPL,root-hub-depth", 
                0x1E, 
                "AAPL,XHC-clock-id", 
                One, 
                "model", 
                Buffer () { "XHCI Controller - 15 Ports" }, 
                "name", 
                Buffer () { "XHCI" }, 
                "AAPL,slot-name", 
                Buffer () { "Built In" }, 
                "device_type", 
                Buffer () { "USB Controller" }, 
                "built-in", 
                Buffer (One) { 0x01 }
            }, Local0)
            
            DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
            Return (Local0)
        }
    }
}

// MARK: - 7. 20 USB Ports Configuration (HS01-HS20, SS01-SS20)
DefinitionBlock ("", "SSDT", 2, "SYSM", "XHC20", 0x00000000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)
    External (DTGP, MethodObj)

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

        Device (XHC)
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

            // USB 2.0 Ports (20 ports)
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

            // USB 3.0+ Ports (20 ports)
            Device (SS01) { Name (_ADR, 0x11) }
            Device (SS02) { Name (_ADR, 0x12) }
            Device (SS03) { Name (_ADR, 0x13) }
            Device (SS04) { Name (_ADR, 0x14) }
            Device (SS05) { Name (_ADR, 0x15) }
            Device (SS06) { Name (_ADR, 0x16) }
            Device (SS07) { Name (_ADR, 0x17) }
            Device (SS08) { Name (_ADR, 0x18) }
            Device (SS09) { Name (_ADR, 0x19) }
            Device (SS10) { Name (_ADR, 0x1A) }
            Device (SS11) { Name (_ADR, 0x1B) }
            Device (SS12) { Name (_ADR, 0x1C) }
            Device (SS13) { Name (_ADR, 0x1D) }
            Device (SS14) { Name (_ADR, 0x1E) }
            Device (SS15) { Name (_ADR, 0x1F) }
            Device (SS16) { Name (_ADR, 0x20) }
            Device (SS17) { Name (_ADR, 0x21) }
            Device (SS18) { Name (_ADR, 0x22) }
            Device (SS19) { Name (_ADR, 0x23) }
            Device (SS20) { Name (_ADR, 0x24) }
        }
        
        Method (_DSM, 4, NotSerialized)
        {
            Store (Package (0x18)
            {
                "AAPL,current-available", 
                0x09C4, 
                "AAPL,current-extra", 
                0x0BB8, 
                "AAPL,current-in-sleep", 
                0x0BB8, 
                "AAPL,max-port-current-in-sleep", 
                0x09C4, 
                "AAPL,device-internal", 
                Zero, 
                "AAPL,clock-id", 
                Buffer (One) { 0x01 }, 
                "AAPL,root-hub-depth", 
                0x28, 
                "AAPL,XHC-clock-id", 
                One, 
                "model", 
                Buffer () { "XHCI Controller - 20 Ports" }, 
                "name", 
                Buffer () { "XHCI" }, 
                "AAPL,slot-name", 
                Buffer () { "Built In" }, 
                "device_type", 
                Buffer () { "USB Controller" }, 
                "built-in", 
                Buffer (One) { 0x01 }
            }, Local0)
            
            DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
            Return (Local0)
        }
    }
}

// MARK: - 8. 25 USB Ports Configuration (HS01-HS25, SS01-SS25)
DefinitionBlock ("", "SSDT", 2, "SYSM", "XHC25", 0x00000000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)
    External (DTGP, MethodObj)

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

        Device (XHC)
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

            // USB 2.0 Ports (25 ports)
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

            // USB 3.0+ Ports (25 ports)
            Device (SS01) { Name (_ADR, 0x11) }
            Device (SS02) { Name (_ADR, 0x12) }
            Device (SS03) { Name (_ADR, 0x13) }
            Device (SS04) { Name (_ADR, 0x14) }
            Device (SS05) { Name (_ADR, 0x15) }
            Device (SS06) { Name (_ADR, 0x16) }
            Device (SS07) { Name (_ADR, 0x17) }
            Device (SS08) { Name (_ADR, 0x18) }
            Device (SS09) { Name (_ADR, 0x19) }
            Device (SS10) { Name (_ADR, 0x1A) }
            Device (SS11) { Name (_ADR, 0x1B) }
            Device (SS12) { Name (_ADR, 0x1C) }
            Device (SS13) { Name (_ADR, 0x1D) }
            Device (SS14) { Name (_ADR, 0x1E) }
            Device (SS15) { Name (_ADR, 0x1F) }
            Device (SS16) { Name (_ADR, 0x20) }
            Device (SS17) { Name (_ADR, 0x21) }
            Device (SS18) { Name (_ADR, 0x22) }
            Device (SS19) { Name (_ADR, 0x23) }
            Device (SS20) { Name (_ADR, 0x24) }
            Device (SS21) { Name (_ADR, 0x25) }
            Device (SS22) { Name (_ADR, 0x26) }
            Device (SS23) { Name (_ADR, 0x27) }
            Device (SS24) { Name (_ADR, 0x28) }
            Device (SS25) { Name (_ADR, 0x29) }
        }
        
        Method (_DSM, 4, NotSerialized)
        {
            Store (Package (0x18)
            {
                "AAPL,current-available", 
                0x0B54, 
                "AAPL,current-extra", 
                0x0CE4, 
                "AAPL,current-in-sleep", 
                0x0CE4, 
                "AAPL,max-port-current-in-sleep", 
                0x0B54, 
                "AAPL,device-internal", 
                Zero, 
                "AAPL,clock-id", 
                Buffer (One) { 0x01 }, 
                "AAPL,root-hub-depth", 
                0x32, 
                "AAPL,XHC-clock-id", 
                One, 
                "model", 
                Buffer () { "XHCI Controller - 25 Ports" }, 
                "name", 
                Buffer () { "XHCI" }, 
                "AAPL,slot-name", 
                Buffer () { "Built In" }, 
                "device_type", 
                Buffer () { "USB Controller" }, 
                "built-in", 
                Buffer (One) { 0x01 }
            }, Local0)
            
            DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
            Return (Local0)
        }
    }
}

// MARK: - 9. 30 USB Ports Configuration (HS01-HS30, SS01-SS30)
DefinitionBlock ("", "SSDT", 2, "SYSM", "XHC30", 0x00000000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)
    External (DTGP, MethodObj)

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

        Device (XHC)
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

            // USB 2.0 Ports (30 ports)
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

            // USB 3.0+ Ports (30 ports)
            Device (SS01) { Name (_ADR, 0x11) }
            Device (SS02) { Name (_ADR, 0x12) }
            Device (SS03) { Name (_ADR, 0x13) }
            Device (SS04) { Name (_ADR, 0x14) }
            Device (SS05) { Name (_ADR, 0x15) }
            Device (SS06) { Name (_ADR, 0x16) }
            Device (SS07) { Name (_ADR, 0x17) }
            Device (SS08) { Name (_ADR, 0x18) }
            Device (SS09) { Name (_ADR, 0x19) }
            Device (SS10) { Name (_ADR, 0x1A) }
            Device (SS11) { Name (_ADR, 0x1B) }
            Device (SS12) { Name (_ADR, 0x1C) }
            Device (SS13) { Name (_ADR, 0x1D) }
            Device (SS14) { Name (_ADR, 0x1E) }
            Device (SS15) { Name (_ADR, 0x1F) }
            Device (SS16) { Name (_ADR, 0x20) }
            Device (SS17) { Name (_ADR, 0x21) }
            Device (SS18) { Name (_ADR, 0x22) }
            Device (SS19) { Name (_ADR, 0x23) }
            Device (SS20) { Name (_ADR, 0x24) }
            Device (SS21) { Name (_ADR, 0x25) }
            Device (SS22) { Name (_ADR, 0x26) }
            Device (SS23) { Name (_ADR, 0x27) }
            Device (SS24) { Name (_ADR, 0x28) }
            Device (SS25) { Name (_ADR, 0x29) }
            Device (SS26) { Name (_ADR, 0x2A) }
            Device (SS27) { Name (_ADR, 0x2B) }
            Device (SS28) { Name (_ADR, 0x2C) }
            Device (SS29) { Name (_ADR, 0x2D) }
            Device (SS30) { Name (_ADR, 0x2E) }
        }
        
        Method (_DSM, 4, NotSerialized)
        {
            Store (Package (0x18)
            {
                "AAPL,current-available", 
                0x0CE4, 
                "AAPL,current-extra", 
                0x0E10, 
                "AAPL,current-in-sleep", 
                0x0E10, 
                "AAPL,max-port-current-in-sleep", 
                0x0CE4, 
                "AAPL,device-internal", 
                Zero, 
                "AAPL,clock-id", 
                Buffer (One) { 0x01 }, 
                "AAPL,root-hub-depth", 
                0x3C, 
                "AAPL,XHC-clock-id", 
                One, 
                "model", 
                Buffer () { "XHCI Controller - 30 Ports" }, 
                "name", 
                Buffer () { "XHCI" }, 
                "AAPL,slot-name", 
                Buffer () { "Built In" }, 
                "device_type", 
                Buffer () { "USB Controller" }, 
                "built-in", 
                Buffer (One) { 0x01 }
            }, Local0)
            
            DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
            Return (Local0)
        }
    }
}

// MARK: - USB Port Mapper (UIAC) - Generates port mapping for macOS
DefinitionBlock ("", "SSDT", 2, "SYSM", "UIAC", 0x00000000)
{
    External (_SB_.PC00.XHCI, DeviceObj)
    
    Scope (\_SB.PC00.XHCI)
    {
        Method (_DSM, 4, NotSerialized)
        {
            Store (Package (0x02)
            {
                "AAPL,current-available", 
                0x0834, 
                "AAPL,current-extra", 
                0x0A8C
            }, Local0)
            
            Return (Local0)
        }
    }
}

// MARK: - USB Injector (Simplified Port Configuration)
DefinitionBlock ("", "SSDT", 2, "SYSM", "USBX", 0x00001000)
{
    // This SSDT injects USB properties into XHCI
    Scope (\_SB.PC00)
    {
        Device (XHCI)
        {
            Name (_ADR, 0x00140000)  // Standard XHCI address
            Method (_STA, 0, NotSerialized)
            {
                Return (0x0F)
            }
            
            Name (_DSD, Package (0x02)
            {
                ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
                Package (0x08)
                {
                    "port-count", 
                    Buffer (0x04) { 0x0F, 0x00, 0x00, 0x00 },  // 15 ports
                    "ports", 
                    Package (0x0F)  // Example for 15 ports
                    {
                        "HS01", 
                        Package (0x04) { "port", Buffer() {0x01}, "UsbConnector", 0x03 },
                        "HS02", 
                        Package (0x04) { "port", Buffer() {0x02}, "UsbConnector", 0x03 },
                        "HS03", 
                        Package (0x04) { "port", Buffer() {0x03}, "UsbConnector", 0x03 },
                        "HS04", 
                        Package (0x04) { "port", Buffer() {0x04}, "UsbConnector", 0x03 },
                        "HS05", 
                        Package (0x04) { "port", Buffer() {0x05}, "UsbConnector", 0x03 },
                        "HS06", 
                        Package (0x04) { "port", Buffer() {0x06}, "UsbConnector", 0x03 },
                        "HS07", 
                        Package (0x04) { "port", Buffer() {0x07}, "UsbConnector", 0x03 },
                        "HS08", 
                        Package (0x04) { "port", Buffer() {0x08}, "UsbConnector", 0x03 },
                        "HS09", 
                        Package (0x04) { "port", Buffer() {0x09}, "UsbConnector", 0x03 },
                        "HS10", 
                        Package (0x04) { "port", Buffer() {0x0A}, "UsbConnector", 0x03 },
                        "HS11", 
                        Package (0x04) { "port", Buffer() {0x0B}, "UsbConnector", 0x03 },
                        "HS12", 
                        Package (0x04) { "port", Buffer() {0x0C}, "UsbConnector", 0x03 },
                        "HS13", 
                        Package (0x04) { "port", Buffer() {0x0D}, "UsbConnector", 0x03 },
                        "HS14", 
                        Package (0x04) { "port", Buffer() {0x0E}, "UsbConnector", 0x03 },
                        "HS15", 
                        Package (0x04) { "port", Buffer() {0x0F}, "UsbConnector", 0x03 }
                    }
                }
            })
        }
    }
}

// MARK: - USB Wake Fix (GPRW)
DefinitionBlock ("", "SSDT", 2, "SYSM", "GPRW", 0x00000000)
{
    // Fix for USB wake issues
    Scope (\)
    {
        Method (GPRW, 2, NotSerialized)
        {
            If (LAnd (LEqual (Arg0, 0x0D), LEqual (Arg1, 0x03)))
            {
                Return (Package (0x02) { 0x03, Zero })
            }
            
            If (LAnd (LEqual (Arg0, 0x0D), LEqual (Arg1, 0x04)))
            {
                Return (Package (0x02) { 0x04, Zero })
            }
            
            Return (Package (0x02) { Arg0, Arg1 })
        }
    }
}

// ============================================================================
// END OF USB SSDT COLLECTION
// ============================================================================