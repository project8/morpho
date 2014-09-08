/*
* MC Krypton Model (Frequency Analysis Model)
* -----------------------------------------------------
* Author: J. A. Formaggio <josephf@mit.edu>
*
* Date: 23 July 2014
*
* Purpose: 
*
*		Program will analyze a set of sampled data from krypton runs
*
*
* Collaboration:  Project 8
*/


functions{

// Set up constants 

	real m_electron() { return  510998.910;}				 // Electron mass in eV
	real c() { return  299792458.;}			   	   	    	 // Speed of light in m/s
	real omega_c() {return 1.758820088e+11;}		         // Angular gyromagnetic ratio in rad Hz/Tesla
	real freq_c() {return omega_c()/(2. * pi());}			 // Gyromagnetic ratio in Hz/Tesla
	real alpha() { return 7.29735257e-3;}               	   	 // Fine structure constant
	real bohr_radius() { return 5.2917721092e-11;}	 	 // Bohr radius in meters
	real r0_electron() { return square(alpha())*bohr_radius();}  // Electron radius

// Method for converting kinetic energy (eV) to frequency (Hz).  
// Depends on magnetic field (Tesla)

   	real get_frequency(real kinetic_energy,real field) {
	     real gamma;
	     gamma <- 1. +  kinetic_energy/m_electron();
	     return freq_c() / gamma * field;
	}

// Method for converting frequency (Hz) to kinetic energy (eV)
// Depends on magnetic field (Tesla)

   	real get_kinetic_energy(real frequency, real field) {
	     real gamma;
	     gamma <- freq_c() / frequency * field;
	     return (gamma -1.) * m_electron();
	}

//  Create a centered normal distribution function for faster convergence on normal distributions

	real vnormal_lp(real beta_raw, real mu, real sigma) {
	       beta_raw ~ normal(0,1);
	       return mu + beta_raw * sigma;
	}

//  Create a centered normal distribution function for faster convergence on cauchy distributions.
//  IMPORTANT: The beta_raw input must be distributed within bounds of -pi/2 to +pi/2.

	real vcauchy_lp(real beta_raw, real mu, real sigma) {
	       beta_raw ~ uniform(-pi()/2. , +pi()/2.);
	       return mu +  tan(beta_raw) * sigma;
	}

}

data {

//   Number of signal and background models

	int<lower=0> nSignals;

//   Primary magnetic field (in Tesla)

     	real<lower=0> BField;
	real<lower=0> BFieldError;

//   Secondary trapping magnetic field (in Tesla/milliAmp).  Error in Tesla.  Current in milliAmperes. 

     	real BCoil;
	real BCoilError;
  	real TrapCurrent;

//   Local oscillator and main mixer offset and error (in Hz)

   	real fclock;
  	real fclockError;
	real LOFreq;

//   Range for fits (in Hz)

  	real<lower=0 > minFreq;
  	real<lower=minFreq> maxFreq;

//   Broadening due to measurement

  	real frequencyWidth;

//   Observed data (frequency and frequency loss).  Measured in Hz and Hz/s.

	int <lower=0> nData;
	vector[nData] freq_data;

//   Livetime weighting

	vector[nData] LivetimeWeight;

}   

transformed data {
	    
        real minKE;
	real maxKE;
	vector[nData] RunLivetime;

	minKE <- get_kinetic_energy(maxFreq, BField);
	maxKE <- get_kinetic_energy(minFreq, BField);

	RunLivetime <- 1.0 ./ LivetimeWeight;

}

parameters {

	vector[2] uNormal;
	real<lower=-pi()/2,upper=+pi()/2> uCauchy;

	vector<lower=0.0>[nSignals] SourceMean;
	vector<lower=0.0>[nSignals] SourceWidth;
	vector[nSignals] SourceSkew;
	simplex[nSignals] SourceStrength;

}

transformed parameters {

	real TrappingField;
	real MainField;
	real TotalField;

	real freq_shift;
	real dfWidth;
	real df;

	vector[nData] frequency; 

// Calculate primary magnetic field, trapping coil effect and total (minimum) field

	MainField <-  vnormal_lp(uNormal[1], BField, BFieldError);

	TrappingField <-  vnormal_lp(uNormal[2], BCoil, BCoilError) * TrapCurrent;

	TotalField <- MainField + TrappingField;

//  Calculate the smear of the frequency due to windowing and clock error (plus clock shift).  Assume cauchy distribution.

        freq_shift <- fclock + LOFreq;

	dfWidth <- sqrt(square(fclockError) + square(frequencyWidth));

	df <- vcauchy_lp(uCauchy, freq_shift, dfWidth);

//  Calculate observables from data

	frequency <- freq_data + df;

}

model{

	real z;
	vector[nSignals] ps;

//   Loop over events

	for (n in 1:nData) {

//   Allow the kinetic energy to have a cauchy prior drawn from a parent global distribution
	    if (TrapCurrent > 0 && nSignals>0) {	       
		   for (k in 1:nSignals) {
		       z <- (frequency[n] - SourceMean[k])/SourceWidth[k];
	       	       ps[k] <- log(SourceStrength[k]) +  log(RunLivetime[n]) + normal_log(frequency[n], SourceMean[k], SourceWidth[k]);
	   	   }		   
	    }
//  Increment likelihood based on amplitudes

	    increment_log_prob(+log_sum_exp(ps));	
	}

}

generated quantities{
	 
	  vector[nSignals] EnergyMean;
	  vector[nSignals] EnergyWidth;
	  vector[nSignals] EnergySkew;
	  vector[nSignals] freq_gen;
	  vector[nSignals] energy_gen;

	  for (k in 1:nSignals) {
	      EnergyMean[k] <-get_kinetic_energy(SourceMean[k], TotalField);
	      EnergyWidth[k] <- (m_electron() * freq_c() / square(SourceMean[k])) * SourceWidth[k];
	      EnergySkew[k] <-  (m_electron() * freq_c() / square(SourceMean[k])) * SourceSkew[k];
	      freq_gen[k] <- normal_rng(SourceMean[k],SourceWidth[k]);
	      energy_gen[k] <-get_kinetic_energy(freq_gen[k], TotalField);
	  }
}
