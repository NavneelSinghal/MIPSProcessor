#include <bits/stdc++.h>
using namespace std;

#define REP(i, n) for (int i = 0; i < n; ++i)
#define INSTRUCTION_NOT_FOUND 0

const int MAX_INSTR = 1e5;
const int MAX_MEM = 1e7;

int cyc[13] = {0};  // for every instruction we store the number of clock cycles
                    // in this array

string instr[MAX_INSTR];  // array of 10^5 string for instruction memory module

int mem[MAX_MEM] = {0};  // array of 10^7 integer for data memory module
int regs[32] = {0};      // array of 32 integers for the register file

void replace(string &s, char a, char b) {
    REP(i, (int)s.size()) {
        if (s[i] == a) s[i] = b;
    }
}

int regint(string reg) {  // regint takes in a register (like $t0 or t0) and
                          // returns the integer corresponding to the register
    if (reg[0] == '$') {
        reg = reg.substr(1);
    }
    if (reg == "zero")
        return 0;
    else if (reg == "at")
        return 1;
    else if (reg[0] == 'v')
        return 2 + reg[1] - '0';
    else if (reg[0] == 'a')
        return 4 + reg[1] - '0';
    else if (reg[0] == 't' && reg[1] < '8')
        return 8 + reg[1] - '0';
    else if (reg[0] == 't')
        return 24 + reg[1] - '8';
    else if (reg == "sp")
        return 29;
    else if (reg[0] == 's')
        return 16 + reg[1] - '0';
    else if (reg[0] == 'k')
        return 26 + reg[1] - '0';
    else if (reg == "gp")
        return 28;
    else if (reg == "fp")
        return 30;
    else if (reg == "ra")
        return 31;
    else
        return stoi(reg);
}

int main(int argc, char *argv[]) {
    int i = 0;
    int pc = 0;      // pc - program counter
    int cycles = 0;  // cycles - keeps track of number of cycles
    int execed = -1;

    ifstream f;
    f.open(argv[1]);
    string name;
    while (f >> name) {
        int c;
        f >> c;
        if (name == "add")
            cyc[0] = c;
        else if (name == "sub")
            cyc[1] = c;
        else if (name == "sll")
            cyc[2] = c;
        else if (name == "srl")
            cyc[3] = c;
        else if (name == "sw")
            cyc[4] = c;
        else if (name == "lw")
            cyc[5] = c;
        else if (name == "bne")
            cyc[6] = c;
        else if (name == "beq")
            cyc[7] = c;
        else if (name == "blez")
            cyc[8] = c;
        else if (name == "bgtz")
            cyc[9] = c;
        else if (name == "j")
            cyc[10] = c;
        else if (name == "jr")
            cyc[11] = c;
        else if (name == "jal")
            cyc[12] = c;
        else {
            cout << "Wrong instruction\n";
            return 0;
        }
    }
    f.close();
    regs[regint("sp")] = MAX_MEM - 1;
    while (true) {
        getline(cin, instr[i]);
        replace(instr[i], '(', ' ');
        replace(instr[i], ')', ' ');
        replace(instr[i], ',', ' ');
        if (instr[i] == "END_INSTRUCTIONS") {
            break;
        }
        ++i;
    }

    while (true) {
        ++execed;
        string s = instr[pc];
        ++pc;
        vector<string> toks;
        stringstream str(s);
        string inter;
        while (getline(str, inter, ' ')) {
            toks.push_back(inter);
        }
        if (toks[0] == "add") {
            cycles += cyc[0];
            int reg1 = regint(toks[1]);
            int reg2 = regint(toks[2]);
            int reg3 = regint(toks[3]);
            int old2 = regs[reg2];
            int old3 = regs[reg3];
            regs[reg1] = regs[reg2] + regs[reg3];
            cout << "reg[" << reg1 << "] becomes reg[" << reg2 << "] + reg["
                 << reg3 << "] which is " << old2 << " + " << old3 << " = "
                 << regs[reg1] << endl;
        } else if (toks[0] == "sub") {
            cycles += cyc[1];
            int reg1 = regint(toks[1]);
            int reg2 = regint(toks[2]);
            int reg3 = regint(toks[3]);
            int old2 = regs[reg2];
            int old3 = regs[reg3];
            regs[reg1] = regs[reg2] - regs[reg3];
            cout << "reg[" << reg1 << "] becomes reg[" << reg2 << "] - reg["
                 << reg3 << "] which is " << old2 << " - " << old3 << " = "
                 << regs[reg1] << endl;
        } else if (toks[0] == "sll") {
            cycles += cyc[2];
            int reg1 = regint(toks[1]);
            int shift = stoi(toks[3]);
            int reg2 = regint(toks[2]);
            int old2 = regs[reg2];
            regs[reg1] = regs[reg2] << shift;
            cout << "reg[" << reg1 << "] becomes reg[" << reg2 << "] << "
                 << shift << " which is " << old2 << " << " << shift << " = "
                 << regs[reg1] << endl;
        } else if (toks[0] == "srl") {
            cycles += cyc[3];
            int reg1 = regint(toks[1]);
            int shift = stoi(toks[3]);
            int reg2 = regint(toks[2]);
            int old2 = regs[reg2];
            regs[reg1] = regs[reg2] >> shift;
            cout << "reg[" << reg1 << "] becomes reg[" << reg2 << "] >> "
                 << shift << " which is " << old2 << " >> " << shift << " = "
                 << regs[reg1] << endl;
        } else if (toks[0] == "sw") {
            cycles += cyc[4];
            int reg1 = regint(toks[1]);
            int reg2 = regint(toks[3]);
            int offset = stoi(toks[2]);
            mem[offset + regs[reg2]] = regs[reg1];
            cout << "memory location at " << offset + regs[reg2]
                 << " was changed to " << regs[reg1] << endl;

        } else if (toks[0] == "lw") {
            cycles += cyc[5];
            int reg1 = regint(toks[1]);
            int reg2 = regint(toks[3]);
            int offset = stoi(toks[2]);
            regs[reg1] = mem[offset + regs[reg2]];
            cout << "data at location " << offset + regs[reg2]
                 << " was stored at register number " << reg1 << endl;
        } else if (toks[0] == "bne") {
            cycles += cyc[6];
            int reg1 = regint(toks[1]);
            int reg2 = regint(toks[2]);
            int offset = stoi(toks[3]);
            if (regs[reg1] != regs[reg2]) {
                pc += offset;
                cout << "Branch condition true so pc is now " << pc << endl;
            } else {
                cout << "Branch condition false so pc is unchanged\n";
            }
        } else if (toks[0] == "beq") {
            cycles += cyc[7];
            int reg1 = regint(toks[1]);
            int reg2 = regint(toks[2]);
            int offset = stoi(toks[3]);
            if (regs[reg1] == regs[reg2]) {
                pc += offset;
                cout << "Branch condition true so pc is now " << pc << endl;
            } else {
                cout << "Branch condition false so pc is unchanged\n";
            }
        } else if (toks[0] == "blez") {
            cycles += cyc[8];
            int reg1 = regint(toks[1]);
            int offset = stoi(toks[2]);
            if (regs[reg1] <= 0) {
                pc += offset;
                cout << "Branch condition true so pc is now " << pc << endl;
            } else {
                cout << "Branch condition false so pc is unchanged\n";
            }
        } else if (toks[0] == "bgtz") {
            cycles += cyc[9];
            int reg1 = regint(toks[1]);
            int offset = stoi(toks[2]);
            if (regs[reg1] > 0) {
                pc += offset;
                cout << "Branch condition true so pc is now " << pc << endl;
            } else {
                cout << "Branch condition false so pc is unchanged\n";
            }
        } else if (toks[0] == "j") {
            cycles += cyc[10];
            int location = stoi(toks[1]);
            pc = location;
            cout << "Jump instruction encountered, pc is now " << pc << endl;
        } else if (toks[0] == "jr") {
            cycles += cyc[11];
            int reg1 = regint(toks[1]);
            pc = regs[reg1];
            cout << "Jump to register value instruction encountered, pc is now "
                 << pc << endl;

        } else if (toks[0] == "jal") {
            cycles += cyc[12];
            regs[regint("ra")] = pc;
            pc = stoi(toks[1]);
            cout << "Jump and link instruction encountered, pc is now " << pc
                 << " and ra is now " << regs[regint("ra")] << endl;

        } else if (toks[0] == "addi") {
            cycles += 4;
            int reg1 = regint(toks[1]);
            int reg2 = regint(toks[2]);
            int addend = stoi(toks[3]);
            int old2 = regs[reg2];
            regs[reg1] = regs[reg2] + addend;
            cout << "reg[" << reg1 << "] becomes reg[" << reg2 << "] + "
                 << addend << " which is " << old2 << " + " << addend << " = "
                 << regs[reg1] << endl;
        } else if (toks[0] == "END") {
            cout << "End instruction encountered\n";
            break;
        } else {
            cout << "Unrecognised instruction " << toks[0]
                 << ", terminating run\n";
            return 0;
        }
        cout << "Register file contents:\n";
        REP(i, 32) cout << "register " << i << " = " << regs[i] << '\n';
    }

    cout << "Execution successfully completed.\n\n";
    cout << "Printing statistics...\n";
    cout << "Number of clock cycles used = " << cycles << "\n";
    cout << "Average instructions per cycle = "
         << ((float)execed / max(cycles, 1)) << "\n\n";
    cout << "Register file state at the end of execution:\n";
    REP(i, 32) cout << "register " << i << " = " << regs[i] << '\n';
    cout << '\n';
    cout << "Memory state at the end of execution (truncated to the first 20 "
            "elements):\n";
    REP(i, 20) cout << "memory at " << i << " = " << mem[i] << '\n';
    cout << endl;
}
