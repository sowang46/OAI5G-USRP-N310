# pf_ul()

This page shows a brief analysis of the PF scheduler implementation in OAI5G RAN (openairinterface5g/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_ulsch.c).

```bash
void pf_ul(module_id_t module_id,
           frame_t frame,
           sub_frame_t slot,
           NR_UE_info_t *UE_list[],
           int max_num_ue,
           int n_rb_sched,
           uint16_t *rballoc_mask) {

  const int CC_id = 0;
  gNB_MAC_INST *nrmac = RC.nrmac[module_id];
  NR_ServingCellConfigCommon_t *scc = nrmac->common_channels[CC_id].ServingCellConfigCommon;
  
  const int min_rb = 5;
  // UEs that could be scheduled
  UEsched_t UE_sched[MAX_MOBILES_PER_GNB] = {0};
  int remainUEs = max_num_ue;
  int curUE=0;

  /* Loop UE_list to calculate throughput and coeff */
  UE_iterator(UE_list, UE) {

    NR_UE_sched_ctrl_t *sched_ctrl = &UE->UE_sched_ctrl;
    if (UE->Msg4_ACKed != true || sched_ctrl->ul_failure == 1)
      continue;

    LOG_D(NR_MAC,"pf_ul: preparing UL scheduling for UE %04x\n",UE->rnti);
    NR_UE_UL_BWP_t *current_BWP = &UE->current_UL_BWP;

    int rbStart = 0; // wrt BWP start

    const uint16_t bwpSize = current_BWP->BWPSize;
    NR_sched_pusch_t *sched_pusch = &sched_ctrl->sched_pusch;
    const NR_mac_dir_stats_t *stats = &UE->mac_stats.ul;

    /* Calculate throughput */
    const float a = 0.0005f; // corresponds to 200ms window
    const uint32_t b = stats->current_bytes;
    UE->ul_thr_ue = (1 - a) * UE->ul_thr_ue + a * b;

    if(remainUEs == 0)
      continue;

    /* Check if retransmission is necessary */
    sched_pusch->ul_harq_pid = sched_ctrl->retrans_ul_harq.head;
    LOG_D(NR_MAC,"pf_ul: UE %04x harq_pid %d\n",UE->rnti,sched_pusch->ul_harq_pid);
    if (sched_pusch->ul_harq_pid >= 0) {
      /* Allocate retransmission*/
      const int tda = get_ul_tda(nrmac, scc, sched_pusch->slot);
      bool r = allocate_ul_retransmission(nrmac, frame, slot, rballoc_mask, &n_rb_sched, UE, sched_pusch->ul_harq_pid, scc, tda);
      if (!r) {
        LOG_D(NR_MAC, "%4d.%2d UL retransmission UE RNTI %04x can NOT be allocated\n", frame, slot, UE->rnti);
        continue;
      }
      else LOG_D(NR_MAC,"%4d.%2d UL Retransmission UE RNTI %04x to be allocated, max_num_ue %d\n",frame,slot,UE->rnti,max_num_ue);

      /* reduce max_num_ue once we are sure UE can be allocated, i.e., has CCE */
      remainUEs--;
      continue;
    } 

    /* skip this UE if there are no free HARQ processes. This can happen e.g.
     * if the UE disconnected in L2sim, in which case the gNB is not notified
     * (this can be considered a design flaw) */
    if (sched_ctrl->available_ul_harq.head < 0) {
      LOG_D(NR_MAC, "RNTI %04x has no free UL HARQ process, skipping\n", UE->rnti);
      continue;
    }

    const int B = max(0, sched_ctrl->estimated_ul_buffer - sched_ctrl->sched_ul_bytes);
    /* preprocessor computed sched_frame/sched_slot */
    const bool do_sched = nr_UE_is_to_be_scheduled(scc, 0, UE, sched_pusch->frame, sched_pusch->slot, nrmac->ulsch_max_frame_inactivity);

    LOG_D(NR_MAC,"pf_ul: do_sched UE %04x => %s\n",UE->rnti,do_sched ? "yes" : "no");
    if ((B == 0 && !do_sched) || (sched_ctrl->rrc_processing_timer > 0)) {
      continue;
    }

    const NR_bler_options_t *bo = &nrmac->ul_bler;
    const int max_mcs = bo->max_mcs; /* no per-user maximum MCS yet */
    if (bo->harq_round_max == 1)
      sched_pusch->mcs = max_mcs;
    else
      sched_pusch->mcs = get_mcs_from_bler(bo, stats, &sched_ctrl->ul_bler_stats, max_mcs, frame);

    /* Schedule UE on SR or UL inactivity and no data (otherwise, will be scheduled
     * based on data to transmit) */
    if (B == 0 && do_sched) {
      /* if no data, pre-allocate 5RB */
      /* Find a free CCE */
      int CCEIndex = get_cce_index(nrmac,
                                   CC_id, slot, UE->rnti,
                                   &sched_ctrl->aggregation_level,
                                   sched_ctrl->search_space,
                                   sched_ctrl->coreset,
                                   &sched_ctrl->sched_pdcch,
                                   false);
      if (CCEIndex<0) {
        LOG_D(NR_MAC, "%4d.%2d no free CCE for UL DCI UE %04x (BSR 0)\n", frame, slot, UE->rnti);
        continue;
      }

      sched_pusch->nrOfLayers = 1;
      sched_pusch->time_domain_allocation = get_ul_tda(nrmac, scc, sched_pusch->slot);
      sched_pusch->tda_info = nr_get_pusch_tda_info(current_BWP, sched_pusch->time_domain_allocation);
      sched_pusch->dmrs_info = get_ul_dmrs_params(scc,
                                                  current_BWP,
                                                  &sched_pusch->tda_info,
                                                  sched_pusch->nrOfLayers);

      LOG_D(NR_MAC,"Looking for min_rb %d RBs, starting at %d num_dmrs_cdm_grps_no_data %d\n",
            min_rb, rbStart, sched_pusch->dmrs_info.num_dmrs_cdm_grps_no_data);
      const uint16_t slbitmap = SL_to_bitmap(sched_pusch->tda_info.startSymbolIndex, sched_pusch->tda_info.nrOfSymbols);
      while (rbStart < bwpSize && (rballoc_mask[rbStart] & slbitmap) != slbitmap)
        rbStart++;
      if (rbStart + min_rb >= bwpSize) {
        LOG_W(NR_MAC, "cannot allocate continuous UL data for RNTI %04x: no resources (rbStart %d, min_rb %d, bwpSize %d\n",
              UE->rnti,rbStart,min_rb,bwpSize);
        continue;
      }

      sched_ctrl->cce_index = CCEIndex;
      fill_pdcch_vrb_map(nrmac,
                         CC_id,
                         &sched_ctrl->sched_pdcch,
                         CCEIndex,
                         sched_ctrl->aggregation_level);

      NR_sched_pusch_t *sched_pusch = &sched_ctrl->sched_pusch;
      sched_pusch->mcs = min(nrmac->min_grant_mcs, sched_pusch->mcs);
      update_ul_ue_R_Qm(sched_pusch->mcs, current_BWP->mcs_table, current_BWP->pusch_Config, &sched_pusch->R, &sched_pusch->Qm);
      sched_pusch->rbStart = rbStart;
      sched_pusch->rbSize = min_rb;
      sched_pusch->tb_size = nr_compute_tbs(sched_pusch->Qm,
                                            sched_pusch->R,
                                            sched_pusch->rbSize,
                                            sched_pusch->tda_info.nrOfSymbols,
                                            sched_pusch->dmrs_info.N_PRB_DMRS * sched_pusch->dmrs_info.num_dmrs_symb,
                                            0, // nb_rb_oh
                                            0,
                                            sched_pusch->nrOfLayers)
                             >> 3;

      /* Mark the corresponding RBs as used */
      n_rb_sched -= sched_pusch->rbSize;
      for (int rb = 0; rb < sched_ctrl->sched_pusch.rbSize; rb++)
        rballoc_mask[rb + sched_ctrl->sched_pusch.rbStart] ^= slbitmap;

      remainUEs--;
      continue;
    }

    /* Create UE_sched for UEs eligibale for new data transmission*/
    /* Calculate coefficient*/
    const uint32_t tbs = ul_pf_tbs[current_BWP->mcs_table][sched_pusch->mcs];
    float coeff_ue = (float) tbs / UE->ul_thr_ue;
    LOG_D(NR_MAC,"rnti %04x b %d, ul_thr_ue %f, tbs %d, coeff_ue %f\n",
          UE->rnti, b, UE->ul_thr_ue, tbs, coeff_ue);
    UE_sched[curUE].coef=coeff_ue;
    UE_sched[curUE].UE=UE;
    curUE++;
  }

  qsort(UE_sched, sizeof(*UE_sched), sizeofArray(UE_sched), comparator);
  UEsched_t *iterator=UE_sched;
  
  /* Loop UE_sched to find max coeff and allocate transmission */
  while (remainUEs> 0 && n_rb_sched >= min_rb && iterator->UE != NULL) {

    NR_UE_sched_ctrl_t *sched_ctrl = &iterator->UE->UE_sched_ctrl;
    int CCEIndex = get_cce_index(nrmac,
                                 CC_id, slot, iterator->UE->rnti,
                                 &sched_ctrl->aggregation_level,
                                 sched_ctrl->search_space,
                                 sched_ctrl->coreset,
                                 &sched_ctrl->sched_pdcch,
                                 false);

    if (CCEIndex<0) {
      LOG_D(NR_MAC, "%4d.%2d no free CCE for UL DCI UE %04x\n", frame, slot, iterator->UE->rnti);
      iterator++;
      continue;
    }
    else LOG_D(NR_MAC, "%4d.%2d free CCE for UL DCI UE %04x\n",frame,slot, iterator->UE->rnti);

    NR_UE_UL_BWP_t *current_BWP = &iterator->UE->current_UL_BWP;

    NR_sched_pusch_t *sched_pusch = &sched_ctrl->sched_pusch;

    sched_pusch->nrOfLayers = 1;
    sched_pusch->time_domain_allocation = get_ul_tda(nrmac, scc, sched_pusch->slot);
    sched_pusch->tda_info = nr_get_pusch_tda_info(current_BWP, sched_pusch->time_domain_allocation);
    sched_pusch->dmrs_info = get_ul_dmrs_params(scc,
                                                current_BWP,
                                                &sched_pusch->tda_info,
                                                sched_pusch->nrOfLayers);

    int rbStart = 0;
    const uint16_t slbitmap = SL_to_bitmap(sched_pusch->tda_info.startSymbolIndex, sched_pusch->tda_info.nrOfSymbols);
    const uint16_t bwpSize = current_BWP->BWPSize;
    while (rbStart < bwpSize && (rballoc_mask[rbStart] & slbitmap) != slbitmap)
      rbStart++;
    sched_pusch->rbStart = rbStart;
    uint16_t max_rbSize = 1;
    while (rbStart + max_rbSize < bwpSize && (rballoc_mask[rbStart + max_rbSize] & slbitmap) == slbitmap)
      max_rbSize++;

    if (rbStart + min_rb >= bwpSize || max_rbSize < min_rb) {
      LOG_D(NR_MAC, "cannot allocate UL data for RNTI %04x: no resources (rbStart %d, min_rb %d, bwpSize %d)\n", iterator->UE->rnti, rbStart, min_rb, bwpSize);
      iterator++;
      continue;
    } else
      LOG_D(NR_MAC, "allocating UL data for RNTI %04x (rbStart %d, min_rb %d, max_rbSize %d, bwpSize %d)\n", iterator->UE->rnti, rbStart, min_rb, max_rbSize, bwpSize);

    /* Calculate the current scheduling bytes */
    const int B = cmax(sched_ctrl->estimated_ul_buffer - sched_ctrl->sched_ul_bytes, 0);
    /* adjust rbSize and MCS according to PHR and BPRE */
    sched_pusch->mu = scc->uplinkConfigCommon->initialUplinkBWP->genericParameters.subcarrierSpacing;
    if(sched_ctrl->pcmax!=0 ||
       sched_ctrl->ph!=0) // verify if the PHR related parameter have been initialized
      nr_ue_max_mcs_min_rb(current_BWP->scs, sched_ctrl->ph, sched_pusch, current_BWP, min_rb, B, &max_rbSize, &sched_pusch->mcs);

    if (sched_pusch->mcs < sched_ctrl->ul_bler_stats.mcs)
      sched_ctrl->ul_bler_stats.mcs = sched_pusch->mcs; /* force estimated MCS down */

    update_ul_ue_R_Qm(sched_pusch->mcs, current_BWP->mcs_table, current_BWP->pusch_Config, &sched_pusch->R, &sched_pusch->Qm);
    uint16_t rbSize = 0;
    uint32_t TBS = 0;
    nr_find_nb_rb(sched_pusch->Qm,
                  sched_pusch->R,
                  1, // layers
                  sched_pusch->tda_info.nrOfSymbols,
                  sched_pusch->dmrs_info.N_PRB_DMRS * sched_pusch->dmrs_info.num_dmrs_symb,
                  B,
                  min_rb,
                  max_rbSize,
                  &TBS,
                  &rbSize);

    sched_pusch->rbSize = rbSize;
    sched_pusch->tb_size = TBS;
    LOG_D(NR_MAC,"rbSize %d (max_rbSize %d), TBS %d, est buf %d, sched_ul %d, B %d, CCE %d, num_dmrs_symb %d, N_PRB_DMRS %d\n",
          rbSize, max_rbSize,sched_pusch->tb_size, sched_ctrl->estimated_ul_buffer, sched_ctrl->sched_ul_bytes, B,
          sched_ctrl->cce_index,sched_pusch->dmrs_info.num_dmrs_symb,sched_pusch->dmrs_info.N_PRB_DMRS);

    /* Mark the corresponding RBs as used */

    sched_ctrl->cce_index = CCEIndex;
    fill_pdcch_vrb_map(nrmac,
                       CC_id,
                       &sched_ctrl->sched_pdcch,
                       CCEIndex,
                       sched_ctrl->aggregation_level);

    n_rb_sched -= sched_pusch->rbSize;
    for (int rb = 0; rb < sched_ctrl->sched_pusch.rbSize; rb++)
      rballoc_mask[rb + sched_ctrl->sched_pusch.rbStart] ^= slbitmap;

    /* reduce max_num_ue once we are sure UE can be allocated, i.e., has CCE */
    remainUEs--;
    iterator++;
  }
}

```