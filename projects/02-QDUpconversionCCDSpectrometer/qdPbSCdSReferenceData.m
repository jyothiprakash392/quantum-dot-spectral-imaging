function reference = qdPbSCdSReferenceData()
%QDPBSCDSREFERENCEDATA Published PbS/CdS optical and Auger table rows.
%   Values reproduce Tables 1 and 2 of Stylianou et al., Nano Letters
%   (2026), DOI 10.1021/acs.nanolett.6c00158. Core diameter and shell
%   thickness were obtained by the source authors through Maxwell-Garnett
%   analysis, so the near-exact Moreels absorption agreement is not treated
%   as independent optical validation. Whole synthesis series, not rows,
%   are held out when evaluating the Auger learner.

reference = struct();
reference.Series = [ones(4,1);2*ones(4,1);3*ones(5,1)];
reference.Sample = {'core1';'1.1';'1.2';'1.3';'core2';'2.1';'2.2'; ...
    '2.3';'core3';'3.1';'3.2';'3.3';'3.4'};
reference.AbsorptionPeak_nm = [1591;1539;1508;1441;1689;1614;1586; ...
    1539;1808;1744;1673;1596;1554];
reference.FWHM_nm = [92.53;111.06;128.97;146.86;123.57;118.22; ...
    127.05;155.28;130.13;273.65;152.53;144.47;137.16];
reference.SizeDistribution_percent = [3.84;4.65;5.42;6.26;5.11;4.91; ...
    5.28;6.50;5.41;11.33;6.31;6.00;5.73];
reference.PbSCoreDiameter_nm = [6.18;5.87;5.69;5.32;6.79;6.32;6.15; ...
    5.87;7.63;7.17;6.69;6.21;5.96];
reference.CdSShellThickness_nm = [0;0.16;0.25;0.42;0;0.27;0.34;0.51; ...
    0;0.21;0.50;0.72;0.84];
reference.AugerLifetime_ps = [140;180;220;260;160;200;240;280; ...
    180;220;260;300;320];
reference.OuterDiameter_nm = reference.PbSCoreDiameter_nm+ ...
    2*reference.CdSShellThickness_nm;
reference.DOI = '10.1021/acs.nanolett.6c00158';
reference.SourceTables = 'article Tables 1 and 2';
end
