import pandas as pd
import os.path
import logging
from scipy.io import savemat

class OAILogParser():
    '''
        Parse OAI log
    '''

    def __init__(self, fn="", log_type=("", 0), log_entries={}, output_type="pandas", output_path=".") -> None:
        assert os.path.exists(fn), "Log file not exist!"
        assert output_type=="pandas" or output_type=="matlab", "Output type not supoorted!"
        self.logs = {v: [] for k, v in log_entries.items()}
        log_cnt = 0
        with open(fn) as f:
            lines = f.readlines()
            for line in lines:
                if len(line)>log_type[1]+1 and line[log_type[1]:log_type[1]+len(log_type[0])]==log_type[0]:
                    log_cnt += 1
                    for k, v in log_entries.items():
                        self.logs[v] += [int(line[k[0]:k[1]].strip())] if line[k[0]:k[1]].strip().isdigit() else [line[k[0]:k[1]]]
        logging.info(f'[OAILogParser]  Matched {log_cnt} logs {log_type[0]}')
        self.__absSFN()
        if output_type=="pandas":
            self.logs = pd.DataFrame(self.logs)
            logging.info(f'[OAILogParser]  Converted log to Pandas DataFrame')
        else:
            savemat(output_path, self.logs)
            logging.critical(f'[OAILogParser]  .m log saved to {output_path}')

    def __absSFN(self):
        '''
            Convert frame/slot to absolute slot and 
            create Pandas DataFrame
        '''
        frame_cycle = 0
        last_frame = self.logs['frame'][0]
        frame_offset = self.logs['frame'][0]
        slot_offset = self.logs['slot'][0]
        self.logs['sn'] = []
        self.logs['fn'] = []
        for ii in range(len(self.logs['frame'])):
            if self.logs['frame'][ii]<last_frame:
                frame_cycle += 1
            self.logs['fn'].append(frame_cycle*1024+self.logs['frame'][ii]-frame_offset)
            # Numerology is fixed to 1 (30KHz)
            self.logs['sn'].append((frame_cycle*1024+self.logs['frame'][ii]-frame_offset)*20+self.logs['slot'][ii]-slot_offset)
            last_frame = self.logs['frame'][ii]

    def __len__(self):
        return len(self.logs)

    def __getitem__(self, key):
        return self.logs[key]

if __name__=="__main__":
    logging.basicConfig(level=logging.INFO)

    log_type = ("[DLSCH/PDSCH/PUCCH]", 23)
    log_entries = { (15, 19)   : "frame",
                    (20, 22)   : "slot",
                    (48, 52)   : "rnti",
                    (67, 70)   : "rbStart",
                    (75, 78)   : "rbSize",
                    (91, 93)   : "startSymbolIndex",
                    (104, 106) : "nrOfSymbols",
                    (123, 125) : "MCS",
                    (137, 138) : "nrOfLayers",
                    (143, 147) : "TBS",
                   }
    sample_mac_log = OAILogParser(fn="../../examples/0118_debug_log_1_various_rate.log", log_type=log_type, log_entries=log_entries, 
                                output_type="matlab", output_path="../0118_debug_log_1_mac.mat")

    log_type = ("[RLC_BUFFER]", 28)
    log_entries = { (20, 24)   : "frame",
                    (25, 27)   : "slot",
                    (73, 79)   : "UE",
                    (81, 89)   : "size"
                   }
    
    sample_rlc_buffer_log = OAILogParser(fn="../../examples/0118_debug_log_1_various_rate.log", log_type=log_type, log_entries=log_entries, 
                                output_type="matlab", output_path="../0118_debug_log_1_rlc.mat")