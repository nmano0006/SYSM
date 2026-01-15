DefinitionBlock ("", "SSDT", 2, "ACDT", "ALTCPU", 0x00000000)
{
    External (_SB_.PR00, DeviceObj)
    External (_SB_.PR01, DeviceObj)
    External (_SB_.PR02, DeviceObj)
    External (_SB_.PR03, DeviceObj)
    External (_SB_.PR04, DeviceObj)
    External (_SB_.PR05, DeviceObj)
    External (_SB_.PR06, DeviceObj)
    External (_SB_.PR07, DeviceObj)
    External (_SB_.PR08, DeviceObj)
    External (_SB_.PR09, DeviceObj)
    External (_SB_.PR0A, DeviceObj)
    External (_SB_.PR0B, DeviceObj)
    External (_SB_.PR0C, DeviceObj)
    External (_SB_.PR0D, DeviceObj)
    External (_SB_.PR0E, DeviceObj)
    External (_SB_.PR0F, DeviceObj)
    External (_SB_.PR10, DeviceObj)
    External (_SB_.PR11, DeviceObj)
    External (_SB_.PR12, DeviceObj)
    External (_SB_.PR13, DeviceObj)
    External (_SB_.PR14, DeviceObj)
    External (_SB_.PR15, DeviceObj)
    External (_SB_.PR16, DeviceObj)
    External (_SB_.PR17, DeviceObj)

    Scope (\_SB.PR00)
    {
        Method (_DSM, 4, NotSerialized)
        {
            If ((Arg2 == Zero))
            {
                Return (Buffer (One)
                {
                     0x03
                })
            }

            Return (Package (0x04)
            {
                "plugin-type", 
                One, 
                "ioname", 
                "cpus"
            })
        }
    }
}
