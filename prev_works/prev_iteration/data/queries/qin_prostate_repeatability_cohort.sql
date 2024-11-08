WITH
  # we know there is only one prostate segmentation per study
  idc_seg_whole_prostate AS (
  SELECT
    segmentations.StudyInstanceUID,
    segmentations.SeriesInstanceUID,
    segmentations.segmented_SeriesInstanceUID,
    # for debugging:
    dicom_all.SeriesDescription
  FROM
    `bigquery-public-data.idc_current.segmentations` AS segmentations
  JOIN
    `bigquery-public-data.idc_current.dicom_all` AS dicom_all
  ON
    segmentations.SeriesInstanceUID = dicom_all.SeriesInstanceUID
  WHERE
    dicom_all.SeriesDescription = "T2 Weighted Axial Segmentations"
    AND segmentations.SegmentedPropertyType.CodeValue = 'T-9200B'
    AND segmentations.SegmentedPropertyType.CodingSchemeDesignator = 'SRT'),
  # select T2, here we do not check for multiple T2 within the same study, since we know there is only one per study
  t2_series AS(
  SELECT
    DISTINCT dc_all.SeriesInstanceUID,
    dc_all.StudyInstanceUID,
    dc_all.PatientID
  FROM
    `bigquery-public-data.idc_current.dicom_all` AS dc_all
  WHERE
    dc_all.collection_id = 'qin_prostate_repeatability'
    AND dc_all.Modality = 'MR'
    AND LOWER(dc_all.SeriesDescription) LIKE '%t2%'
  ORDER BY
    PatientID),
  # ADC selection
  adc_series AS(
  SELECT
    dc_adc.StudyInstanceUID,
    ARRAY_AGG(dc_adc.SeriesInstanceUID
    ORDER BY
      dc_adc.SeriesDate, dc_adc.SeriesTime DESC
    LIMIT
      1)[SAFE_OFFSET(0)] AS SeriesInstanceUID,
  FROM
    `bigquery-public-data.idc_current.dicom_all` AS dc_adc
  JOIN
    t2_series
  ON
    dc_adc.StudyInstanceUID = t2_series.StudyInstanceUID
  WHERE
    LOWER(dc_adc.SeriesDescription) LIKE '%apparent%'
  GROUP BY
    dc_adc.StudyInstanceUID)
SELECT
  t2_series.SeriesInstanceUID AS t2_serieUID,
  adc_series.SeriesInstanceUID AS adc_serieUID,
  idc_seg_whole_prostate.SeriesInstanceUID AS expertWholeProstateSeriesInstanceUID,
  idc_seg_whole_prostate.SeriesDescription AS expertWholeProstateSeriesDescription,
  t2_series.StudyInstanceUID
FROM
  t2_series
INNER JOIN
  adc_series
ON
  t2_series.StudyInstanceUID = adc_series.StudyInstanceUID
INNER JOIN
  idc_seg_whole_prostate
ON
  t2_series.SeriesInstanceUID = idc_seg_whole_prostate.segmented_SeriesInstanceUID
