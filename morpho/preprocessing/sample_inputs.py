'''
Select Stan "data" parameter inputs by sampling from priors.

Below is an example preprocessing configuration dictionary.

preprocessing:
  which_pp:
    - method_name: sample_inputs
      module_name: sample_inputs
      params_to_sample:
        - Q
        - sigma_value
      prior_dists:
        - normal
        - normal
      priors:
        - [18575., 0.2]
        - [0.04, 0.004]
      fixed_params: {'KEmin':18574., 'KEmax':18575.4, 'background_fraction':0.05, 'sigma_error':0.004, 'u_value':0, 'u_spread':70, 'mass':0.2} 
      output_file_name: "./tritium_model/results/beta_spectrum_2-19_ensemble.root" 
      tree: inputs
'''


import logging
logger = logging.getLogger(__name__)

try:
    import ROOT as ROOT# import ROOT, TStyle, TCanvas, TH1F, TGraph, TLatex, TLegend, TFile, TTree, TGaxis, TRandom3, TNtuple, TTree
    import numpy as np
    import random
    from array import array
except ImportError:
    pass


def sample_inputs(param_dict):
    outfile = ROOT.TFile(param_dict['output_file_name'],"RECREATE")
    # Create a ROOT tree
    out_tree = ROOT.TTree(param_dict['tree'], param_dict['tree'])

    for i in range(len(param_dict['params_to_sample'])):
        if param_dict['prior_dists'][i] == 'normal':
            param_name = param_dict['params_to_sample'][i]
            tmp_sampled_val = array('f',[ 0 ])
            b = out_tree.Branch(param_name, tmp_sampled_val, param_name+'/F')
            random.seed()
            rand = random.gauss(param_dict['priors'][i][0], param_dict['priors'][i][1])
            logger.info('Sampled value of {}: {}'.format(param_name, rand))
            tmp_sampled_val[0] = rand
            b.Fill()

        else:
            logger.debug('Sampling for {} distributions is not yet implemented'.format(param_dict['prior_dists'][i]))

    for key in param_dict['fixed_params']:
        tmp_fixed_val = array('f',[ 0 ])
        b = out_tree.Branch(key, tmp_fixed_val, key+'/F')
        tmp_fixed_val[0] = param_dict['fixed_params'][key]
        b.Fill()

    out_tree.Fill()
    outfile.Write()               
    outfile.Close()
