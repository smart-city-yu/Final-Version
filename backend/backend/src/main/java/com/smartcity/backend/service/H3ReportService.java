package com.smartcity.backend.service;


import com.smartcity.backend.GeoUtil;
import com.smartcity.backend.model.H3TokenAgg;
import com.smartcity.backend.model.Report;
import com.smartcity.backend.model.ReportH3;
import com.smartcity.backend.repository.H3TokenAggRepository;
import com.smartcity.backend.repository.ReportH3Repository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor

public class H3ReportService {
    private final ReportH3Repository reportH3Repository;
    private final H3TokenAggRepository h3TokenAggRepository;
    private final H3CoreService h3Core;


    public List<Report> getAllReports(List<Long> h3Token) {
        return reportH3Repository.getAllReportByH3Tokens(h3Token);
    }


    public List<H3TokenAgg> getReportAgg(List<Long> tokens) {
        return h3TokenAggRepository.findAllById(tokens);
    }

    public void InsertReportH3(Report report ) {
        for (int i = 1 ; i<=12; i++) {
            Long inx = h3Core.getCell(report.getLat() , report.getLon() , i);
            reportH3Repository.save(ReportH3.builder()
                    .h3Token(inx)
                    .report(report)
                    .build());
            H3TokenAgg agg = new H3TokenAgg();
            if (h3TokenAggRepository.existsById(inx)){
                Optional<H3TokenAgg> h3TokenAgg = h3TokenAggRepository.findById(inx);
                agg = h3TokenAgg.orElseGet(H3TokenAgg::new);

            }
            if (agg.getH3TokenId()==null)
                agg.setH3TokenId(inx);
            double[] XYZ = GeoUtil.toXYZ(report.getLat() , report.getLon());
            agg.setX(agg.getX() + XYZ[0]);
            agg.setY(agg.getY() + XYZ[1]);
            agg.setZ(agg.getZ() + XYZ[2]);
            agg.setCount(agg.getCount() + 1);
            h3TokenAggRepository.save(agg);

        }
    }







}
