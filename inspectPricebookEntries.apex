List<PricebookEntry> entries = [
    SELECT
        Id,
        Product2Id,
        Product2.Name,
        Product2.ProductCode,
        Pricebook2Id,
        Pricebook2.Name,
        Pricebook2.IsStandard,
        UnitPrice,
        IsActive
    FROM PricebookEntry
    WHERE IsActive = true
    AND Product2.IsActive = true
    ORDER BY Product2.Name, Pricebook2.Name, UnitPrice
];

for (PricebookEntry pbe : entries) {
    System.debug(
        'PBE=' + pbe.Id +
        ' | PRODUCT=' + pbe.Product2Id +
        ' | NAME=' + pbe.Product2.Name +
        ' | CODE=' + pbe.Product2.ProductCode +
        ' | PRICEBOOK=' + pbe.Pricebook2.Name +
        ' | STANDARD=' + pbe.Pricebook2.IsStandard +
        ' | PRICE=' + pbe.UnitPrice +
        ' | ACTIVE=' + pbe.IsActive
    );
}
