// In SSDTGeneratorView, update the motherboardModels array:

let motherboardModels = [
    // Gigabyte
    
    DefinitionBlock ("", "SSDT", 2, "SYSM ", "DTPG", 0x00001000)
    {
        Method (DTGP, 5, NotSerialized)
        {
            If ((Arg0 == ToUUID ("a0b5b7c6-1318-441c-b0c9-fe695eaf949b") /* Unknown UUID */))
            {
                If ((Arg1 == One))
                {
                    If ((Arg2 == Zero))
                    {
                        Arg4 = Buffer (One)
                            {
                                 0x03                                             // .
                            }
                        Return (One)
                    }

                    If ((Arg2 == One))
                    {
                        Return (One)
                    }
                }
            }

            Arg4 = Buffer (One)
                {
                     0x00                                             // .
                }
            Return (Zero)
        }
    }


    DefinitionBlock ("", "SSDT", 2, "SYSM", "ALS0", 0)
    {
        Scope (\)
        {
            Device (ALS0)
            {
                Name (_HID, "ACPI0008")
                Name (_CID, "PNP0C50")
                Method (_STA, 0, NotSerialized)
                {
                    If (_OSI ("Darwin"))
                    {
                        Return (0x0F)
                    }
                    Return (0)
                }
                Name (_ALI, 0x0140)
            }
        }
    }
    DefinitionBlock ("", "SSDT", 2, "SYSM", "AWAC", 0x00000000)
    {
        // External references (if needed)
       External (_SB_.PC00, DeviceObj)

        Scope (\_SB.PC00)
        {
            Device (RTC)
            {
                Name (_HID, "PNP0B00" /* AT Real-Time Clock */)  // _HID: Hardware ID
                Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
                {
                    IO (Decode16,
                        0x0070,             // Range Minimum
                        0x0070,             // Range Maximum
                        0x01,               // Alignment
                        0x02,               // Length
                        )
                    IO (Decode16,
                        0x0072,             // Range Minimum
                        0x0072,             // Range Maximum
                        0x01,               // Alignment
                        0x06,               // Length
                        )
                })
                Name (_STA, 0x0B)  // _STA: Status
            }

            Device (AWAC)
            {
                Name (_HID, "ACPI000E" /* Time and Alarm Device */)  // _HID: Hardware ID
                Name (_STA, Zero)  // _STA: Status
            }
        }
    }
    DefinitionBlock ("", "SSDT", 2, "SYSM", "EC", 0x00000000)
    {
         External (_SB_.PC00.LPCB, DeviceObj)
        External (_SB_.PC00.LPCB.H_EC, DeviceObj)

        Device (EC)
        {
            Name (_HID, EisaId ("PNP0C09") /* Embedded Controller Device */)  // _HID: Hardware ID
            Name (_UID, One)  // _UID: Unique ID
            Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
            {
                IO (Decode16,
                    0x0062,             // Range Minimum
                    0x0062,             // Range Maximum
                    0x01,               // Alignment
                    0x01,               // Length
                    )
                IO (Decode16,
                    0x0066,             // Range Minimum
                    0x0066,             // Range Maximum
                    0x01,               // Alignment
                    0x01,               // Length
                    )
            })
            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                Return (0x0F)
            }

            Method (_REG, 2, NotSerialized)  // _REG: Region Availability
            {
            }
        }
    }

    DefinitionBlock ("", "SSDT", 2, "SYSM", "FWHD", 0x00000000)
    {
        External (_SB_.PC00, DeviceObj)
        External (_SB_.PC00.LPCB, DeviceObj)

        Scope (\_SB.PC00.LPCB)
        {
            Device (FWHD)
            {
                Name (_HID, EisaId ("INT0800"))  // Intel Firmware Hub Device
                Name (_CID, EisaId ("PNP0C02"))  // Plug and Play ID for system board
                Name (_UID, 0x01)
                
                Method (_STA, 0, NotSerialized)
                {
                    // Enable only in macOS
                    If (_OSI ("Darwin"))
                    {
                        Return (0x0F)  // Device present, enabled, shown in UI
                    }
                    Else
                    {
                        Return (0x00)  // Device not present in other OS
                    }
                }
                
                // Memory resources for firmware hub
                Name (_CRS, ResourceTemplate ()
                {
                    Memory32Fixed (ReadWrite,
                        0xFED10000,         // Base address
                        0x00001000,         // Length (4KB)
                        )
                        
                    Memory32Fixed (ReadWrite,
                        0xFED18000,         // Base address
                        0x00001000,         // Length (4KB)
                        )
                        
                    // Optional: I/O resources if needed
                    // IO (Decode16,
                    //     0x1000,             // Range Minimum
                    //     0x1000,             // Range Maximum
                    //     0x01,               // Alignment
                    //     0x10,               // Length
                    //     )
                })
                
                // Device Specific Method
                Method (_DSM, 4, Serialized)
                {
                    Local0 = Package (0x02)
                    {
                        // UUID for Intel Firmware Hub: 1F1B4BC5-8B86-48B5-816D-184C131D9D8E
                        ToUUID ("1F1B4BC5-8B86-48B5-816D-184C131D9D8E"),
                        
                        Package ()
                        {
                            // "fwhub-state" property
                            "fwhub-state",
                            Buffer (0x01) { 0x01 }  // Enabled
                        }
                    }
                    Return (Local0)
                }
            }
        }
    }
    DefinitionBlock ("", "SSDT", 2, "SYSM", "HIDD", 0x00000000)
    {
     External (_SB_.PC00, DeviceObj)
        External (_SB_.PC00.LPCB, DeviceObj)

        
        Scope (\_SB.PC00.LPCB)
        {
            Device (HIDD)
            {
                Name (_HID, "PNP0C50")  // HID Device
                Name (_CID, "MSFT0001")
                Name (_UID, One)
                
                Method (_STA, 0, NotSerialized)
                {
                    If (_OSI ("Darwin"))
                    {
                        Return (0x0B)  // Present and enabled
                    }
                    Return (Zero)
                }
                
                Name (_CRS, ResourceTemplate ()
                {
                    IO (Decode16, 0x0060, 0x0060, 0x01, 0x01)
                    IO (Decode16, 0x0064, 0x0064, 0x01, 0x01)
                    IRQ (Edge, ActiveHigh, Exclusive, ) {1}
                })
                
                // Simple _DSM method
                Method (_DSM, 4, Serialized)
                {
                    Return (Package (0x02)
                    {
                        ToUUID ("3D6D021E-F9B9-4B44-AD8F-B0ABE4FCFFD1"),
                        Package ()
                        {
                            "HIDWakeup",
                            Buffer (One) { 0x01 }
                        }
                    })
                }
            }
        }
    }
    DefinitionBlock ("", "SSDT", 2, "SYSM", "LPCB", 0x00000000)
    {
        // External references (if needed)
        External (_SB_.PC00, DeviceObj)
        External (_SB_.PC00.LPCB, DeviceObj)

        Scope (_SB.PC00.LPCB)
        {
            Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
            {
                If (!Arg2)
                {
                    Return (Buffer (One)
                    {
                         0x03                                             // .
                    })
                }

                Return (Package (0x0A)
                {
                    "device-id",
                    Buffer (0x04)
                    {
                         0x04, 0x7A, 0x00, 0x00                           // .z..
                    },

                    "AAPL,slot-name",
                    Buffer (0x08)
                    {
                        "LPC Bus"
                    },

                    "model-name",
                    Buffer (0x15)
                    {
                        "Intel LPC Controller"
                    },

                    "name",
                    Buffer (0x10)
                    {
                        "pci8086,7a04"
                    },

                    "compatible",
                    Buffer (0x0D)
                    {
                        "pci8086,7a04"
                    }
                })
            }
        }
    }

    DefinitionBlock ("", "SSDT", 2, "SYSM", "MEM2", 0x00000000)
    {
        // Simple memory configuration for macOS
        Scope (\_SB)
        {
            Device (MEM0)
            {
                Name (_HID, "PNP0C80")  // Memory Device
                
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
                
                // Memory resources
                Name (_CRS, ResourceTemplate ()
                {
                    // System memory
                    QWordMemory (ResourceConsumer, PosDecode, MinFixed, MaxFixed, Cacheable, ReadWrite,
                        0x0000000000000000,
                        0x0000000000000000,
                        0xFFFFFFFFFFFFFFFF,
                        0x0000000000000000,
                        0x0000000800000000,  // 32GB
                        ,, , AddressRangeMemory, TypeStatic)
                })
            }
        }
    }
    
    DefinitionBlock ("", "SSDT", 2, "SYSM", "NVME", 0x00000000)
    {
        Scope (\_SB.PC00.RP01)
        {
            // First NVMe SSD (M.2 Slot 1)
            Device (NVME)
            {
                Name (_ADR, Zero)
                
                Method (_STA, 0, NotSerialized)
                {
                    // Check if device is present (you can implement detection logic here)
                    Return (0x0F)
                }
                
                // PCI Express Device
                Name (_SUN, 0x01)  // Slot User Number
                
                // Power Management
                Name (_PRW, Package (0x02)
                {
                    0x09,  // GPE number
                    0x03   // Sleep state support (S3)
                })
                
                // PCI Configuration
                Method (_INI, 0, NotSerialized)
                {
                    // Initialization method
                    Store (0x01, PCEJ)  // Enable PCI Express slot
                }
                
                // NVMe-specific properties via _DSM
                Method (_DSM, 4, Serialized)
                {
                    Local0 = Package (0x02)
                    {
                        // NVMe Properties UUID
                        ToUUID ("C5DCDA2A-53C2-481F-BAB5-9F6C79D7C2F5"),
                        
                        Package (0x04)
                        {
                            // "model" - Drive model name
                            "model",
                            Buffer (0x20)
                            {
                                "Samsung SSD 970 EVO Plus 1TB"
                            },
                            
                            // "serial-number" - Drive serial number
                            "serial-number",
                            Buffer (0x14)
                            {
                                "S4EWNF0MC12345"
                            },
                            
                            // "device-type" - NVMe device type
                            "device-type",
                            Buffer (0x04)
                            {
                                0x01, 0x00, 0x00, 0x00  // Non-volatile memory
                            },
                            
                            // "built-in" - Mark as internal device
                            "built-in",
                            Buffer (0x04)
                            {
                                0x01, 0x00, 0x00, 0x00
                            }
                        }
                    }
                    Return (Local0)
                }
            }
            
            // Second NVMe SSD on same port (if bifurcated)
            Device (NVMF)
            {
                Name (_ADR, 0x00010000)
                
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
                
                Name (_SUN, 0x02)
            }
        }
        
        // Second M.2 Slot (RP02)
        Scope (\_SB.PC00.RP02)
        {
            Device (NVME)
            {
                Name (_ADR, Zero)
                
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
                
                Name (_SUN, 0x03)
                
                // Different NVMe properties for second slot
                Method (_DSM, 4, Serialized)
                {
                    Local0 = Package (0x02)
                    {
                        ToUUID ("C5DCDA2A-53C2-481F-BAB5-9F6C79D7C2F5"),
                        
                        Package (0x03)
                        {
                            "model",
                            Buffer (0x20)
                            {
                                "WD Black SN850 2TB"
                            },
                            
                            "serial-number",
                            Buffer (0x14)
                            {
                                "223121801234"
                            },
                            
                            "built-in",
                            Buffer (0x04) { 0x01, 0x00, 0x00, 0x00 }
                        }
                    }
                    Return (Local0)
                }
            }
        }
    }
    DefinitionBlock ("", "SSDT", 2, "SYSM", "PCI0", 0x00000000)
    {
     External (_SB_.PC00, DeviceObj)
        External (_SB_.PC00.SAT0, DeviceObj)
        External (_SB_.PC00.XHCI, DeviceObj)
        External (DTGP, MethodObj)    // 5 Arguments

        Method (_SB.PC00.XHCI._DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
        {
            Local0 = Package (0x1B)
                {
                    "AAPL,slot-name",
                    Buffer (0x09)
                    {
                        "Built In"
                    },

                    "built-in",
                    Buffer (One)
                    {
                         0x00                                             // .
                    },

                    "device-id",
                    Buffer (0x04)
                    {
                         0x7A, 0x60, 0x00, 0x00                           // z`..
                    },

                    "name",
                    Buffer (0x34)
                    {
                        "ASMedia / Intel Z790 Series Chipset XHCI Controller"
                    },

                    "model",
                    Buffer (0x34)
                    {
                        "ASMedia ASM1074 / Intel Z790 Series Chipset USB 3.2"
                    },

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
                    Buffer (One)
                    {
                         0x01                                             // .
                    },

                    "AAPL,root-hub-depth",
                    0x1A,
                    "AAPL,XHC-clock-id",
                    One,
                    Buffer (One)
                    {
                         0x00                                             // .
                    }
                }
            DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
            Return (Local0)
        }

        Method (_SB.PC00.SAT0._DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
        {
            Local0 = Package (0x0C)
                {
                    "AAPL,slot-name",
                    Buffer (0x09)
                    {
                        "Built In"
                    },

                    "built-in",
                    Buffer (One)
                    {
                         0x00                                             // .
                    },

                    "name",
                    Buffer (0x16)
                    {
                        "Intel AHCI Controller"
                    },

                    "model",
                    Buffer (0x1F)
                    {
                        "Intel Z790 Series Chipset SATA"
                    },

                    "device_type",
                    Buffer (0x15)
                    {
                        "AHCI SATA Controller"
                    },

                    "compatible",
                    Buffer (0x0D)
                    {
                        "pci8086,a182"
                    }
                }
            DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
            Return (Local0)
        }
    }

    DefinitionBlock ("", "SSDT", 2, "SYSM", "PLUG", 0x00000000)
    {
          External (_SB_.CP00, ProcessorObj)

        Scope (\_SB.CP00)
        {
            Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
            {
                If (!Arg2)
                {
                    Return (Buffer (One)
                    {
                         0x03                                             // .
                    })
                }

                Return (Package (0x02)
                {
                    "plugin-type",
                    One
                })
            }
        }
    }

    
    DefinitionBlock ("", "SSDT", 2, "SYSM", "PMCR", 0x00000000)
    {
        // External references (if needed)
        External (_SB_.PC00.LPCB, DeviceObj)

        Scope (\_SB.PC00.LPCB)
        {
            Device (PMCR)
            {
                Name (_HID, EisaId ("APP9876"))  // _HID: Hardware ID
                Method (_STA, 0, NotSerialized)  // _STA: Status
                {
                    If (_OSI ("Darwin"))
                    {
                        Return (0x0B)
                    }
                    Else
                    {
                        Return (Zero)
                    }
                }

                Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
                {
                    Memory32Fixed (ReadWrite,
                        0xFE000000,         // Address Base
                        0x00010000,         // Address Length
                        )
                })
            }
        }
    }

    DefinitionBlock ("", "SSDT", 2, "SYSM", "PPMC", 0x00000000)
    {
        External (_SB_.PC00, DeviceObj)
        External (_SB_.PC00.LPCB, DeviceObj)
        
        Scope (\_SB.PC00.LPCB)
        {
            Device (PPMC)
            {
                Name (_HID, "INT3A0D")
                Name (_CID, "PNP0C02")
                Name (_UID, One)
                
                Method (_STA, 0, NotSerialized)
                {
                    If (_OSI ("Darwin"))
                    {
                        Return (0x0B)  // Present and enabled
                    }
                    Return (Zero)
                }
                
                Name (_CRS, ResourceTemplate ()
                {
                    Memory32Fixed (ReadWrite, 0xFED10000, 0x1000, )
                    Memory32Fixed (ReadWrite, 0xFED18000, 0x1000, )
                })
                
                // Basic power management methods
                Method (_PTS, 1, NotSerialized)
                {
                    // Prepare To Sleep - called before entering sleep state
                    // Arg0: 1=S1, 2=S2, 3=S3, 4=S4, 5=S5
                    Store (Arg0, PMSL)
                }
                
                Method (_WAK, 1, NotSerialized)
                {
                    // Wake from Sleep
                    Store (0x00, PMSL)
                    Return (Package (0x02){0x00, 0x00})
                }
                
                Name (PMSL, 0x00)  // Sleep state register
            }
        }
    }
    
    DefinitionBlock ("", "SSDT", 2, "SYSM", "PWRB", 0x00000000)
    {

        External (_SB_.PC00, DeviceObj)
        External (_SB_.PC00.LPCB, DeviceObj)
        External (_SB_.PC00.LPCB.EC, DeviceObj)  // Embedded Controller
    External (\_SB.PWRB, MethodObj)    // 5 Arguments
        
        // Power Button Device under Embedded Controller (recommended for Intel systems)
        Scope (\_SB.PC00.LPCB.EC)
        {
            Device (PWRB)
            {
                Name (_HID, EisaId ("PNP0C0C"))  // Power Button Device
                Name (_CID, "PNP0C0C")
                Name (_UID, 0x01)
                
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)  // Always present and enabled
                }
                
                // Power Button Status
                Name (_PRS, Package (0x02)
                {
                    0x00,   // Not pressed
                    0x01    // Pressed
                })
                
                // Power Button Control Method
                Method (_PRW, 0, NotSerialized)
                {
                    // Power Resources for Wake
                    Return (Package (0x02)
                    {
                        0x1B,  // GPE number for power button (typical: GPE 0x1B or 0x1C)
                        0x03   // Sleep state support (S3 and S4)
                    })
                }
                
                // Power Button Press Method
                Method (_PSW, 1, NotSerialized)
                {
                    // Enable/disable wake capability
                    // Arg0: 0=Disable, 1=Enable
                    Store (Arg0, PWEN)
                }
                
                // Power Button Notify Method
                Method (_PSB, 0, NotSerialized)
                {
                    // Simulate power button press
                    Notify (\_SB.PWRB, 0x80)  // Notify power button event
                }
                
                Name (PWEN, 0x01)  // Power button wake enable
            }
        }
    }
  
    DefinitionBlock ("", "SSDT", 2, "SYSM", "RTC0", 0x00000000)
    {
        // External references (if needed)
     External (_SB_.PC00, DeviceObj)
        External (_SB_.PC00.LPCB, DeviceObj)
        Scope (\_SB.PC00.LPCB)
        {
            Device (RTC0)
            {
                Name (_HID, "PNP0B00")
                Name (_CID, "PNP0B00")
                
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
                
                // Standard RTC I/O ports
                Name (_CRS, ResourceTemplate ()
                {
                    IO (Decode16, 0x0070, 0x0070, 0x01, 0x02)
                    IO (Decode16, 0x0071, 0x0071, 0x01, 0x02)
                    IRQ (Edge, ActiveHigh, Exclusive, ) {8}
                })
            }
        }
    }
    
    DefinitionBlock ("", "SSDT", 2, "SYSM", "SATA", 0x00000000)
    {
        // External references (if needed)
        External (_SB_.PC00, DeviceObj)
      
        External (_SB_.PC00.SAT0, DeviceObj)
    External (DTGP, MethodObj)    // 5 Arguments
        
         Method (_SB.PC00.SAT0._DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
        {
            Local0 = Package (0x0C)
                {
                    "AAPL,slot-name",
                    Buffer (0x09)
                    {
                        "Built In"
                    },

                    "built-in",
                    Buffer (One)
                    {
                         0x00                                             // .
                    },

                    "name",
                    Buffer (0x16)
                    {
                        "Intel AHCI Controller"
                    },

                    "model",
                    Buffer (0x1F)
                    {
                        "Intel Z790 Series Chipset SATA"
                    },

                    "device_type",
                    Buffer (0x15)
                    {
                        "AHCI SATA Controller"
                    },

                    "compatible",
                    Buffer (0x0D)
                    {
                        "pci8086,a182"
                    }
                }
            DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
            Return (Local0)
        }
    }

    DefinitionBlock ("", "SSDT", 2, "SYSM", "SBUS", 0x00000000)
    {
        // External references (if needed)
       External (_SB_.PC00, DeviceObj)
        External (_SB_.PC00.SBUS, DeviceObj)

        Device (_SB.PC00.SBUS.BUS0)
        {
            Name (_CID, "smbus")  // _CID: Compatible ID
            Name (_ADR, Zero)  // _ADR: Address
            Device (DVL0)
            {
                Name (_ADR, 0x57)  // _ADR: Address
                Name (_CID, "diagsvault")  // _CID: Compatible ID
                Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
                {
                    If (!Arg2)
                    {
                        Return (Buffer (One)
                        {
                             0x57                                             // W
                        })
                    }

                    Return (Package (0x02)
                    {
                        "address",
                        0x57
                    })
                }
            }
        }
    }

    DefinitionBlock ("", "SSDT", 2, "SYSM", "TMR", 0x00000000)
    {
    External (_SB_.PC00, DeviceObj)
        External (_SB_.PC00.LPCB, DeviceObj)
        
        Scope (\_SB.PC00.LPCB)
        {
            Device (TMR)
            {
                Name (_HID, "PNP0100")  // System Timer
                Name (_CID, "PNP0100")
                
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
                
                // Standard 8254 timer resources
                Name (_CRS, ResourceTemplate ()
                {
                    IO (Decode16, 0x0040, 0x0040, 0x01, 0x01)
                    IO (Decode16, 0x0041, 0x0041, 0x01, 0x01)
                    IO (Decode16, 0x0042, 0x0042, 0x01, 0x01)
                    IO (Decode16, 0x0043, 0x0043, 0x01, 0x01)
                    IRQ (Edge, ActiveHigh, Exclusive, ) {0}
                })
            }
        }
    }
    DefinitionBlock ("", "SSDT", 2, "SYSM", "XOSI", 0x00000000)
    {
        // External references (if needed)
     Method (XOSI, 1, NotSerialized)
        {
            Local0 = Package (0x0D)
                {
                    "Windows 2000",
                    "Windows 2001",
                    "Windows 2001 SP1",
                    "Windows 2001.1",
                    "Windows 2001 SP2",
                    "Windows 2001.1 SP1",
                    "Windows 2006",
                    "Windows 2006 SP1",
                    "Windows 2006.1",
                    "Windows 2009",
                    "Windows 2012",
                    "Windows 2013",
                    "Windows 2015"
                }
            If (_OSI ("Darwin"))
            {
                Return ((Match (Local0, MEQ, Arg0, MTR, Zero, Zero) != Ones))
            }
            Else
            {
                Return (_OSI (Arg0))
            }
        }
    }

    DefinitionBlock ("", "SSDT", 1, "SYSM", "HDEF", 0x00003000)
    {
        External (_SB_, DeviceObj)
        External (_SB_.PC00, DeviceObj)
        External (_SB_.PC00.HDAS, DeviceObj)
        External (DTGP, MethodObj)    // 5 Arguments

        Scope (\_SB.PC00)
        {
            Device (HDEF)
            {
                Name (_ADR, 0x001F0003)  // _ADR: Address
                Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
                {
                    If ((Arg2 == Zero))
                    {
                        Return (Buffer (One)
                        {
                             0x03                                             // .
                        })
                    }

                    Local0 = Package (0x18)
                        {
                            "layout-id",
                            Buffer (0x04)
                            {
                                 0x07, 0x00, 0x00, 0x00                           // ....
                            },

                            "alc-layout-id",
                            Buffer (0x04)
                            {
                                 0x0C, 0x00, 0x00, 0x00                           // ....
                            },

                            "MaximumBootBeepVolume",
                            Buffer (One)
                            {
                                 0xEF                                             // .
                            },

                            "MaximumBootBeepVolumeAlt",
                            Buffer (One)
                            {
                                 0xF1                                             // .
                            },

                            "multiEQDevicePresence",
                            Buffer (0x04)
                            {
                                 0x0C, 0x00, 0x01, 0x00                           // ....
                            },

                            "AAPL,slot-name",
                            Buffer (0x09)
                            {
                                "Built In"
                            },

                            "model",
                            Buffer (0x39)
                            {
                                "Intel Union Point PCH - High Definition Audio Controller"
                            },

                            "hda-gfx",
                            Buffer (0x0A)
                            {
                                "onboard-1"
                            },

                            "built-in",
                            Buffer (One)
                            {
                                 0x01                                             // .
                            },

                            "device_type",
                            Buffer (0x16)
                            {
                                "High Definition Audio"
                            },

                            "name",
                            Buffer (0x10)
                            {
                                "Realtek ALC1220"
                            },

                            "PinConfigurations",
                            Buffer (Zero){}
                        }
                    DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                    Return (Local0)
                }
            }
        }

        Method (_SB.PC00.HDAS._STA, 0, NotSerialized)  // _STA: Status
        {
            Return (Zero)
        }
    }


]
