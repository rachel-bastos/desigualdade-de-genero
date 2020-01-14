# ==================================================================================================
# Análise sobre a desigualdade de gênero nos municípios brasileiros
# ==================================================================================================

# Instalando e carregando pacotes
if (!require("install.load")) {
  install.packages("install.load")
  library(install.load)
 }
install_load(c("dplyr","rgdal","RColorBrewer","ggplot2","maptools","rgeos","cowplot","stringr"))

# Importando bases de dados dos municípios brasileiros relativa ao Censo de 2010
data <- read.csv("Dados/BASE_MUNICIPIOS.csv", stringsAsFactors = F, encoding = 'UTF-8')
names(data)[1] <- "ID_CIDADE" #problema de encoding

# Importando arquivos shapefile dos municípios brasileiros
shape <- readOGR("Dados/municipios_2010/municipios_2010.shp", layer = "municipios_2010", verbose = FALSE)
shape@data <- shape@data %>% mutate(ID_CIDADE = as.numeric(as.character(codigo_ibg)))
shape@data$id = rownames(shape@data)
shape_points = fortify(shape, region="id")
gdf = left_join(shape_points, shape@data, by="id")

# Selecionando variáveis usadas no estudo
selected_vars = c('ID_CIDADE',
                 'NOME_CIDADE',
                 'UF',
                 'POPULACAO_TOTAL',
                 'PERC_POPULACAO_URBANA',
                 'PERC_POPULACAO_RURAL',
                 'PERC_POPULACAO_MASCULINA',
                 'PERC_POPULACAO_FEMININA',
                 'QTD_ANALFABETO_MAIS_15ANOS',
                 'TAXA_ANALFABETO_MAIS_15',
                 'QTD_DOMICILIOS',
                 'QTD_DOMICILIOS_RESP_HOMEM',
                 'QTD_DOMICILIOS_RESP_MULHER',
                 'PERC_DOMICILIOS_SANEAMENTO_ADEQUADO',
                 'PERC_DOMICILIOS_SANEAMENTO_SEMI_ADEQUADO',
                 'PERC_DOMICILIOS_SANEAMENTO_SEMI_INADEQUADO',
                 'MEDIA_REND_DOMICILIAR_PERCAPITA_NOM',
                 'MEDIA_REND_NOMINAL_HOMENS',
                 'MEDIA_REND_NOMINAL_MULHERES',
                 'MEDIANA_REND_NOMINAL_HOMENS',
                 'MEDIANA_REND_NOMINAL_MULHERES')

data <- data %>% select(selected_vars)

# Valores faltantes coletados a parte no banco de dados SIDRA
complement <- read.csv2("Dados/COLETA_COMPLEMENTAR.csv", stringsAsFactors = F)
data <- rbind(data, complement)

# Imputação de dados
# Fernando de Noronha, PE - QTD_ANALFABETO_MAIS_15ANOS = 105, POP_MAIS_15ANOS = 2094, TAXA_ANALFABETO_MAIS_15 = 105/2094*10000 = 501,4
# Sena Madureira, AC - POPULACAO_TOTAL = 38029, POP_URBANA = 25112, POP_RURAL = 12917, PERC_POPULACAO_URBANA = 25112/38029*100 = 66,03,  PERC_POPULACAO_RURAL = 12917/38029*100 = 33,97, 
# POP_MASCULINA = 19739, POP_FEMININA = 18290, PERC_POPULACAO_MASCULINA = 19739/38029*100 = 51,9, PERC_POPULACAO_FEMININA = 18290/38029*100 = 48,1

data <- data %>%
  mutate(QTD_ANALFABETO_MAIS_15ANOS = replace(QTD_ANALFABETO_MAIS_15ANOS, ID_CIDADE == 2605459, 105),
         TAXA_ANALFABETO_MAIS_15 = replace(TAXA_ANALFABETO_MAIS_15, ID_CIDADE == 2605459, 501.4),
         POPULACAO_TOTAL = replace(POPULACAO_TOTAL, ID_CIDADE == 1200500, 38029),
         PERC_POPULACAO_URBANA = replace(PERC_POPULACAO_URBANA, ID_CIDADE == 1200500, 66.03),
         PERC_POPULACAO_RURAL = replace(PERC_POPULACAO_RURAL, ID_CIDADE == 1200500, 33.97),
         PERC_POPULACAO_MASCULINA = replace(PERC_POPULACAO_MASCULINA, ID_CIDADE == 1200500, 51.9),
         PERC_POPULACAO_FEMININA = replace(PERC_POPULACAO_FEMININA, ID_CIDADE == 1200500, 48.1)
         ) 

data <- data %>% replace(., is.na(.), 0)

# Criação de variáeis
data <- data %>% mutate(
  QTD_ANALFABETO_HOMENS = PERC_POPULACAO_MASCULINA/100*QTD_ANALFABETO_MAIS_15ANOS,
  QTD_ANALFABETO_MULHERES = PERC_POPULACAO_FEMININA/100*QTD_ANALFABETO_MAIS_15ANOS,
  RAZAO_SEXO_ANALFABETISMO = QTD_ANALFABETO_HOMENS/QTD_ANALFABETO_MULHERES,
  RAZAO_SEXO_DOM_RESPONSAVEL = QTD_DOMICILIOS_RESP_HOMEM/QTD_DOMICILIOS_RESP_MULHER,
  RAZAO_SEXO_RENDA_MENSAL = MEDIANA_REND_NOMINAL_HOMENS/MEDIANA_REND_NOMINAL_MULHERES
)

# Análises prévias
create_map <- function(data, gdf, column, labels = NULL, discrete = FALSE){

  df <- data %>% select(c('ID_CIDADE',column))
  names(df)[2] <- "value"
  gdf <- left_join(gdf, df, by='ID_CIDADE')

  if(discrete)
    breaks <- seq(1,max(gdf$value))
  else
    breaks <- waiver()
    
  if(is.null(labels))
    labels <- waiver()
  
  map <- ggplot() + 
    geom_polygon(data=gdf, aes(x = long, y = lat, group = group, fill = value)) +
    scale_fill_viridis_c(option = "C", breaks=breaks, labels=labels) +
    labs(x='', y='') +
    theme_bw() + theme(panel.grid.major = element_blank(), 
                       panel.grid.minor = element_blank(),
                       panel.border = element_blank(),
                       legend.title = element_blank(),
                       legend.text = element_text(size=20),
                       axis.line = element_blank(),
                       axis.text = element_blank(),
                       axis.ticks = element_blank(),
                       strip.background = element_rect(colour="white", fill="#ffffff"))
  return(map)
}

create_map(data, gdf, 'RAZAO_SEXO_DOM_RESPONSAVEL')
ggsave('MAPA_RAZAO_SEXO_DOM_RESPONSAVEL.png', dpi = 300, width = 25, height = 20, units = 'cm', path = 'gráficos/')

create_map(data, gdf, 'RAZAO_SEXO_RENDA_MENSAL')
ggsave('MAPA_RAZAO_SEXO_RENDA_MENSAL.png', dpi = 300, width = 25, height = 20, units = 'cm', path = 'gráficos/')

create_map(data, gdf, 'RAZAO_SEXO_ANALFABETISMO')
ggsave('MAPA_RAZAO_SEXO_ANALFABETISMO.png', dpi = 300, width = 25, height = 20, units = 'cm', path = 'gráficos/')

mean(data$PERC_POPULACAO_MASCULINA)
mean(data$PERC_POPULACAO_FEMININA)
mean(data$QTD_ANALFABETO_MULHERES/(data$QTD_ANALFABETO_HOMENS+data$QTD_ANALFABETO_MULHERES))

summary_measures <- data %>% summarise(  media_responsavel = mean(RAZAO_SEXO_DOM_RESPONSAVEL),
                     media_analfabetismo = mean(RAZAO_SEXO_ANALFABETISMO),
                     media_renda = mean(RAZAO_SEXO_RENDA_MENSAL),
                     mediana_responsavel = median(RAZAO_SEXO_DOM_RESPONSAVEL),
                     mediana_analfabetismo = median(RAZAO_SEXO_ANALFABETISMO),
                     mediana_renda = median(RAZAO_SEXO_RENDA_MENSAL),
                     q3_renda = quantile(RAZAO_SEXO_RENDA_MENSAL, .75))

# Porcentagem de municípios em que a maioria dos domicílios está sob responsabilidade de mulheres
(data %>% filter(RAZAO_SEXO_DOM_RESPONSAVEL < 1) %>% nrow())/nrow(data)*100
# Porcentagem de municípios em que a renda mensal mediana dos homens é superior a das mulheres
(data %>% filter(RAZAO_SEXO_RENDA_MENSAL > 1) %>% nrow())/nrow(data)*100
# Porcentagem de municípios em que o número de homens analfabetos é superior ao de mulheres analfabetas
(data %>% filter(RAZAO_SEXO_ANALFABETISMO < 1) %>% nrow())/nrow(data)*100

# Clusterização
set.seed(9999999)

cluster_vars = c('RAZAO_SEXO_DOM_RESPONSAVEL',
                 'RAZAO_SEXO_RENDA_MENSAL',
                 'RAZAO_SEXO_ANALFABETISMO')

X <- data %>% select(cluster_vars)
km <- kmeans(X, 3)
hc <- hclust(dist(X), method="complete")

data <- data %>% mutate(Kmeans = km$cluster, Hcl = cutree(hc, k = 3))
write.csv2(data, 'output/data.csv', row.names = F)

gen_avgK <- data %>% group_by(Kmeans) %>% summarise(
  municipios = length(Kmeans),
  responsavel = mean(RAZAO_SEXO_DOM_RESPONSAVEL),
  analfabetismo = mean(RAZAO_SEXO_ANALFABETISMO),
  renda = mean(RAZAO_SEXO_RENDA_MENSAL))

write.csv2(gen_avgK, "output/médias_cluster_kmeans.csv", row.names = FALSE)

gen_avgH <- data %>% group_by(Hcl) %>% summarise(
  municipios = length(Hcl),
  responsavel = mean(RAZAO_SEXO_DOM_RESPONSAVEL),
  analfabetismo = mean(RAZAO_SEXO_ANALFABETISMO),
  renda = mean(RAZAO_SEXO_RENDA_MENSAL))

write.csv2(gen_avgK, "output/médias_h_culster.csv", row.names = FALSE)

create_map(data, gdf, 'Kmeans', discrete = T, labels = c("Desigualdade","Igualdade","Semi-Igualdade"))
ggsave('MAPA_KMEANS.png', dpi = 300, width = 25, height = 20, units = 'cm', path = 'gráficos/')


# Índice
X <- data %>% select(cluster_vars)
pca <- princomp(X)

pca_weights <- pca$loadings
write.csv2(pca_weights, 'output/loadings.csv')

ranking <- data %>% select(ID_CIDADE, NOME_CIDADE, UF) %>% mutate(Local = paste(NOME_CIDADE,'-',UF),Indice = pca$scores[,1])
write.csv2(ranking, 'output/ranking_pca.csv', row.names = F)

top10_educacao <- arrange(ranking, Indice)[1:10,] %>% mutate(Esfera = 'Educação')
top10_lar <- arrange(ranking, desc(Indice))[1:10,] %>% mutate(Esfera = 'Participação no Lar')
top_mun <- rbind(top10_educacao, top10_lar)


ggplot(top_mun, aes(x = reorder(Local, -Indice), y = Indice, color = Esfera)) + 
  geom_segment( aes(x=reorder(Local, -Indice), xend=reorder(Local, -Indice), 
                    y=0, yend=Indice), color='grey') +
  geom_point(size=4) +
  coord_flip()+
  scale_color_manual(values=c('#58355E','#7AE7C7'))+
  labs(x='', y='',title='Índice de Desigualdade de Gênero') + 
  theme_light() +
  theme(
    panel.grid.major.x = element_blank(),
    panel.border = element_blank(),
    axis.ticks.x = element_blank()
  ) 
  
ggsave('ranking_desigualdade.png', dpi = 300, width = 20, height = 15, units = 'cm', path = 'gráficos/')