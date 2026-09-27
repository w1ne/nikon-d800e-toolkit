import com.nikonhacker.Constants;
import com.nikonhacker.Prefs;
import com.nikonhacker.emu.*;
import com.nikonhacker.emu.memory.DebuggableMemory;
import com.nikonhacker.disassembly.CPUState;
import com.nikonhacker.emu.trigger.condition.BreakPointCondition;

import java.io.File;

/**
 * Head-less probe of the D800E FR firmware (B block as extracted; the emulator
 * loads it at FrCPUState.RESET_ADDRESS = 0x40000, so memory = file + 0x40000).
 *
 * usage: D800Probe <b63e111b.bin> [fn_address] [g rec q]...
 *   default fn_address = 0x61DE2 (the bitrate dispatcher)
 *   top of the 4 MiB 0xFF cave is used as scratch RAM/stack.
 *
 * With no case arguments it runs the stock-matrix self-test cases.
 */
public class D800Probe {
    public static void main(String[] args) throws Exception {
        File img = new File(args[0]);
        int fn = args.length > 1 ? Integer.decode(args[1]) : 0x61DE2;

        int SP = 0x65F000, HALT = 0x650000, OUT1 = 0x650100, OUT2 = 0x650104;

        EmulationFramework fw = new EmulationFramework(new Prefs());
        fw.initialize(Constants.CHIP_FR, img);
        Platform p = fw.getPlatform(Constants.CHIP_FR);
        DebuggableMemory mem = p.getMemory();
        CPUState cpu = p.getCpuState();
        Emulator emu = fw.getEmulator(Constants.CHIP_FR);
        emu.setContext(mem, cpu, p.getInterruptController());

        mem.changeProtection(0x650000, 0x10000, true, true, true);
        // map a writable page at 0x84E6C000 (hook PoC marker lives there)
        File markerPage = File.createTempFile("d800probe-marker", ".bin");
        markerPage.deleteOnExit();
        java.io.FileOutputStream fos = new java.io.FileOutputStream(markerPage);
        fos.write(new byte[0x1000]);
        fos.close();
        mem.loadFile(markerPage, 0x84E6C000, false);
        mem.store16(HALT, 0xe0ff); // self-loop break target

        int[][] cases;
        if (args.length > 2) {
            cases = new int[(args.length - 2) / 3][3];
            for (int i = 0; i < cases.length; i++)
                for (int j = 0; j < 3; j++)
                    cases[i][j] = Integer.decode(args[2 + i * 3 + j]);
        } else {
            cases = new int[][]{{0,0,0},{0,2,0},{0,2,1},{0,3,0},{0,6,0},{0,1,0},
                                {1,0,0},{1,1,0},{1,2,0},{1,2,1},{1,5,0},{1,6,1},
                                {2,2,0},{2,2,1},{3,0,0}};
        }

        for (int[] c : cases) {
            // dispatcher takes out1 in R7 and out2 as stack arg ([FP+0x18]);
            // pre-fill the stack window so the right slot holds OUT2.
            for (int off = -0x80; off <= 0x40; off += 4) mem.store32(SP + off, OUT2);
            mem.store32(OUT1, 0);
            mem.store32(OUT2, 0);
            cpu.setReg(4, c[0]);
            cpu.setReg(5, c[1]);
            cpu.setReg(6, c[2]);
            cpu.setReg(7, OUT1);  // out pointer 1
            cpu.setReg(15, SP);   // R15 = SP
            cpu.setReg(17, HALT); // RP
            cpu.setPc(fn);
            emu.clearBreakConditions();
            emu.addBreakCondition(new BreakPointCondition(HALT, null));
            String err = "";
            try {
                emu.play();
            } catch (Exception e) {
                err = "  [emulation: " + e.getClass().getSimpleName() + "]";
            }
            System.out.printf("g=%d rec=%d q=%d -> %,d / %,d%s%n",
                    c[0], c[1], c[2], mem.load32(OUT1), mem.load32(OUT2), err);
        }
        System.out.printf("marker=0x%08X%n", mem.load32(0x84E6C020));
        fw.dispose();
    }
}
