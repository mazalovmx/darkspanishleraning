# Побочные расследования: 108 квестов и 108 боевых встреч

Статус: авторские данные для последующего подключения, **не доступная для прохождения кампания**.
Источник: `game/content/scenario/side_investigations.json`. Файл не подключён к карте или NPC.
Условие подключения — Gate I, рабочие бои стеками, сохранения и учебные блоки.
Основные смерти, исчезновение Эстебана и природа El Índice не переписаны.

Это 12 оригинальных расследований по 9 отдельных заданий: материальные признаки,
ошибки чтения, ложные обвинения, проверка документов и ограниченные выводы. Общая
основа — учёная тайна и семиотический детектив, без переноса персонажей или фабул Эко.

## Что именно добавлено

- 108 квестов SX001–SX108, с условиями, уликой, альтернативными толкованиями и решением.
- 108 непотребляемых артефактов AX001–AX108 с происхождением и пределами доказательства.
- 108 боевых конфигураций BX001–BX108: 2–3 вражеских стека, причина столкновения,
  мирный доступ, отступление без потери улик. **Баланс не проверен в боевой сцене.**
- 108 задач на сопоставление доказательства и вывода; ещё 12 головоломок с акростихами.
- 24 локальных исхода (публикация или защищённая копия) и 12 необязательных связей между ветками.
- Каждое задание требует активной испанской речи. Выбор ответа сам по себе его не завершает.

## Как устроены развилки

Внутри каждой ветки: 1 → {2,3}; 2 → 4; 3 → 5; {4,5} → 6;
6 → {7,8}; {7,8} → 9. Ветки независимы; связи между их финалами необязательны.
Коллекция предметов не заменяет сравнение объяснений и письменный ответ.
Неправильная версия даёт возможность вернуться к наблюдениям, не уничтожает артефакт.

Сложность языка следует блокам 1,1,2,2,3,4,5,6,7. Номер квеста **не открывает**
новую грамматику: доступ к заданию требует закрепления предыдущих учебных блоков.
Каждая языковая задача предусматривает образец, выполнение с опорой, самостоятельную
формулировку и отложенное воспроизведение. Грамматика не проверяется во время боя.
Автономная ветка без API использует заданную опору и сохраняет ответ; это не имитация
автоматической оценки свободной речи. Система исполнения этих условий ещё не подключена.

## Объём и границы

Это расширение по запросу пользователя поверх шести исходных SQ01–SQ06; их IDs и
смысл сохранены. Новые задания имеют отдельное пространство SX. Полное прохождение
расширения не обещает уложиться в исходные 8–10 часов; темп требует плейтеста.
Бои — варианты конфликта, а не обязательные 108 убийств. Победа обеспечивает доступ
к предмету, но не определяет истинность обвинения. Мирный путь сохраняет обучение.
Новые абстрактные эффекты способностей — контракт данных для будущей интеграции,
а не заявление об уже работающих боевых механиках.

## Расследования и полный список заданий

### SB01. El censo bajo la oración — LOC01

Завязка: Un registro de limosnas parece demostrar que doce familias jamás existieron.

Авторское решение (спойлер): Un administrador reutilizó hojas de un censo para borrar deudas caritativas; no borró personas de la historia.

Цена решения: Recuperar derechos sin publicar domicilios de familias perseguidas.

| Квест | Название | Артефакт | Испанский блок | Бой |
|---|---|---|---:|---|
| SX001 | La hoja que pesa | folio de limosnas | 1 | BX001 |
| SX002 | El borde sin cortar | tira de pergamino | 1 | BX002 |
| SX003 | La cuenta del raspador | recibo del raspador | 2 | BX003 |
| SX004 | Dos tintas y una jarra | muestra de tinta | 2 | BX004 |
| SX005 | La firma ausente | resguardo de entrega | 3 | BX005 |
| SX006 | El banco de los doce | tablilla de turnos | 4 | BX006 |
| SX007 | Una deuda sin sujeto | glosa contable | 5 | BX007 |
| SX008 | La copia del invierno | duplicado fechado | 6 | BX008 |
| SX009 | Doce nombres públicos | carpeta de restitución | 7 | BX009 |

### SB02. Las horas prestadas — LOC01

Завязка: Dos testigos sitúan una entrega en horas incompatibles porque cada uno oyó una campana distinta.

Авторское решение (спойлер): Un reloj fue adelantado para acortar el descanso de los trabajadores; el desfase se usó después como coartada.

Цена решения: Corregir el reloj sin convertir una confusión horaria en acusación de asesinato.

| Квест | Название | Артефакт | Испанский блок | Бой |
|---|---|---|---:|---|
| SX010 | La cuerda azul | cuerda marcada | 1 | BX010 |
| SX011 | La esfera torcida | esfera suelta | 1 | BX011 |
| SX012 | El jornal del ajuste | vale del relojero | 2 | BX012 |
| SX013 | El peso de plomo | pesa horaria | 2 | BX013 |
| SX014 | Antes del relevo | ficha de relevo | 3 | BX014 |
| SX015 | El descanso pequeño | cartilla de descanso | 4 | BX015 |
| SX016 | La frase prestada | declaración copiada | 5 | BX016 |
| SX017 | Tres relojes | hoja de contraste | 6 | BX017 |
| SX018 | La coartada corregida | cronología doble | 7 | BX018 |

### SB03. El atlas de la sed — LOC06

Завязка: Un mapa oficial convierte un canal comunal en una propiedad privada.

Авторское решение (спойлер): Una leyenda cartográfica fue cambiada; el cauce no cambió, pero la licencia resultante sí excluyó a sus usuarios.

Цена решения: Recuperar acceso al agua sin provocar una inundación sobre los barrios bajos.

| Квест | Название | Артефакт | Испанский блок | Бой |
|---|---|---|---:|---|
| SX019 | La línea doble | plano de acequia | 1 | BX019 |
| SX020 | Piedra con nivel | mojón de agua | 1 | BX020 |
| SX021 | El precio del cubo | tarifa sellada | 2 | BX021 |
| SX022 | La cuerda de medir | cordel graduado | 2 | BX022 |
| SX023 | La compuerta nocturna | registro de apertura | 3 | BX023 |
| SX024 | El cauce de antes | cuaderno de barquero | 4 | BX024 |
| SX025 | Una palabra al margen | glosa de servidumbre | 5 | BX025 |
| SX026 | La prueba de la esclusa | tabla de caudales | 6 | BX026 |
| SX027 | El derecho y la corriente | expediente del canal | 7 | BX027 |

### SB04. Los vecinos de nadie — LOC02

Завязка: Vecinos vivos figuran como fallecidos en un padrón que decide quién recibe comida.

Авторское решение (спойлер): La copia de una columna de traslado como fallecimiento borró derechos; un arrendador aprovechó el error para tomar viviendas.

Цена решения: Restituir identidades sin revelar refugios clandestinos.

| Квест | Название | Артефакт | Испанский блок | Бой |
|---|---|---|---:|---|
| SX028 | La casilla negra | ficha vecinal | 1 | BX028 |
| SX029 | Un rostro y dos números | medalla de vecindad | 1 | BX029 |
| SX030 | La ración duplicada | vale de harina | 2 | BX030 |
| SX031 | El precio del nombre | tarifa de registro | 2 | BX031 |
| SX032 | El entierro ajeno | acta funeraria | 3 | BX032 |
| SX033 | La casa ocupada | contrato de arriendo | 4 | BX033 |
| SX034 | La columna corrida | matriz del padrón | 5 | BX034 |
| SX035 | El testigo reservado | certificado de comparecencia | 6 | BX035 |
| SX036 | Un nombre restituido | resolución de rectificación | 7 | BX036 |

### SB05. Los animales del margen — LOC03

Завязка: Un bestiario parece señalar a vecinos como herejes, aunque sus dibujos nacieron como marcas de taller.

Авторское решение (спойлер): Las figuras eran códigos de encuadernación; un denunciante convirtió índices materiales en juicios morales.

Цена решения: Deshacer una lista acusatoria sin ocultar el plagio real de un académico.

| Квест | Название | Артефакт | Испанский блок | Бой |
|---|---|---|---:|---|
| SX037 | El pez sin agua | hoja del pez | 1 | BX037 |
| SX038 | La cabra del lomo | lomo marcado | 1 | BX038 |
| SX039 | El pedido del cuervo | orden de tinta | 2 | BX039 |
| SX040 | Tres pieles por hoja | muestrario | 2 | BX040 |
| SX041 | El dibujo añadido | calco del margen | 3 | BX041 |
| SX042 | El uso del taller | manual de aprendiz | 4 | BX042 |
| SX043 | La llave del índice | índice de cuadernos | 5 | BX043 |
| SX044 | La cita sin dueño | pliego de fuentes | 6 | BX044 |
| SX045 | El juicio del lobo | dossier de símbolos | 7 | BX045 |

### SB06. La luz con dueño — LOC03

Завязка: Un instrumento atribuido a un santo parece curar solo a quienes pagan a una cofradía.

Авторское решение (спойлер): Un disco graduado mejora la lectura al filtrar deslumbramiento; la cofradía selecciona los casos fáciles para anunciar curaciones.

Цена решения: Dar acceso al instrumento sin prometer curaciones que no ofrece.

| Квест | Название | Артефакт | Испанский блок | Бой |
|---|---|---|---:|---|
| SX046 | El disco ahumado | disco de lectura | 1 | BX046 |
| SX047 | Las ranuras gemelas | montura doble | 1 | BX047 |
| SX048 | El donativo fijo | lista de donativos | 2 | BX048 |
| SX049 | La medida de letras | cartilla tipográfica | 2 | BX049 |
| SX050 | El ensayo repetido | ficha de ensayo | 3 | BX050 |
| SX051 | Los pacientes omitidos | libro de admisión | 4 | BX051 |
| SX052 | Una palabra demasiado grande | certificado de mejoría | 5 | BX052 |
| SX053 | El cristal compartido | licencia de uso | 6 | BX053 |
| SX054 | La promesa limitada | informe de acceso | 7 | BX054 |

### SB07. El sello que pesa — LOC05

Завязка: Sacos legales de sal pesan menos al pasar aduana, y todos llevan un sello auténtico.

Авторское решение (спойлер): La balanza usa una pesa hueca y el sello certifica origen, no cantidad; funcionarios y comerciantes discuten qué ignoraban.

Цена решения: Restituir pérdidas sin paralizar el abastecimiento del puerto.

| Квест | Название | Артефакт | Испанский блок | Бой |
|---|---|---|---:|---|
| SX055 | El saco intacto | precinto de sal | 1 | BX055 |
| SX056 | La pesa que suena | pesa hueca | 1 | BX056 |
| SX057 | El precio de la libra | tarifa portuaria | 2 | BX057 |
| SX058 | La cuerda y el fiel | patrón de contraste | 2 | BX058 |
| SX059 | La descarga anterior | talón de muelle | 3 | BX059 |
| SX060 | El hábito del pesador | libreta de aprendiz | 4 | BX060 |
| SX061 | Origen no es cantidad | manual del sello | 5 | BX061 |
| SX062 | La restitución parcial | tabla de lotes | 6 | BX062 |
| SX063 | La sal y el hambre | convenio provisional | 7 | BX063 |

### SB08. El libro de los sanos — LOC15

Завязка: Dos hospitales anuncian resultados opuestos usando partes del mismo registro.

Авторское решение (спойлер): Uno cuenta ingresos y otro altas, ocultando traslados; el sesgo de selección favorece una subvención.

Цена решения: Publicar una comparación honesta preservando nombres y tratamientos privados.

| Квест | Название | Артефакт | Испанский блок | Бой |
|---|---|---|---:|---|
| SX064 | La columna cortada | hoja de ingresos | 1 | BX064 |
| SX065 | El brazalete ajeno | brazalete de traslado | 1 | BX065 |
| SX066 | La cama pagada | recibo de cama | 2 | BX066 |
| SX067 | El agua del lavado | orden de compra | 2 | BX067 |
| SX068 | El alta y el carro | parte de transporte | 3 | BX068 |
| SX069 | Los casos elegidos | cuaderno de sala | 4 | BX069 |
| SX070 | El denominador perdido | tabla de porcentajes | 5 | BX070 |
| SX071 | La copia sin nombres | registro anonimizado | 6 | BX071 |
| SX072 | Curar la estadística | informe comparativo | 7 | BX072 |

### SB09. La vara del maestro — LOC04

Завязка: Aprendices fracasan en una prueba de precisión porque el patrón cambia entre examen y venta.

Авторское решение (спойлер): El gremio usa patrones distintos para restringir licencias; una reforma sin compensación amenaza a pequeños talleres.

Цена решения: Unificar medidas sin arruinar a quienes trabajaban honestamente con otro patrón.

| Квест | Название | Артефакт | Испанский блок | Бой |
|---|---|---|---:|---|
| SX073 | Dos varas iguales | varas de taller | 1 | BX073 |
| SX074 | La muesca muda | plantilla de aprendiz | 1 | BX074 |
| SX075 | El derecho de examen | recibo de licencia | 2 | BX075 |
| SX076 | El lote devuelto | muestra de bisagras | 2 | BX076 |
| SX077 | La noche del patrón | acta de sustitución | 3 | BX077 |
| SX078 | Lo que medían antes | libro de encargos | 4 | BX078 |
| SX079 | La copia con condición | estatuto de medida | 5 | BX079 |
| SX080 | El adaptador de hierro | calibre de conversión | 6 | BX080 |
| SX081 | La medida del daño | plan de transición | 7 | BX081 |

### SB10. El correo de los ausentes — LOC11

Завязка: Cartas que nunca llegaron se venden como prueba de abandono familiar.

Авторское решение (спойлер): Un desvío postal lucrativo acumuló cartas; algunos destinatarios prefieren conservar el silencio para escapar de vínculos abusivos.

Цена решения: Reparar el desvío sin obligar a nadie a revelar su paradero.

| Квест | Название | Артефакт | Испанский блок | Бой |
|---|---|---|---:|---|
| SX082 | El saco sin camino | saco de correo | 1 | BX082 |
| SX083 | La cera rehecha | sello recalentado | 1 | BX083 |
| SX084 | Un porte dos veces | recibo postal | 2 | BX084 |
| SX085 | La caja del retorno | ficha de devolución | 2 | BX085 |
| SX086 | El carro detenido | registro de postas | 3 | BX086 |
| SX087 | La ruta que no era | mapa del cartero | 4 | BX087 |
| SX088 | No contestar no es morir | declaración de búsqueda | 5 | BX088 |
| SX089 | La dirección reservada | instrucción de entrega | 6 | BX089 |
| SX090 | El derecho al silencio | acta de entrega | 7 | BX090 |

### SB11. La letanía del aire — LOC08

Завязка: Una oración minera parece predecir derrumbes, pero oculta una secuencia de mantenimiento.

Авторское решение (спойлер): La letanía preservó un protocolo técnico; los dueños la usaban como ritual sin ejecutar sus pasos.

Цена решения: Recuperar el protocolo sin confundirlo con una garantía absoluta de seguridad.

| Квест | Название | Артефакт | Испанский блок | Бой |
|---|---|---|---:|---|
| SX091 | La tablilla de cinco versos | tablilla de relevo | 1 | BX091 |
| SX092 | La rueda inmóvil | pasador de rueda | 1 | BX092 |
| SX093 | El aceite cambiado | vale de mantenimiento | 2 | BX093 |
| SX094 | La cuerda de ensayo | medidor de corriente | 2 | BX094 |
| SX095 | La marca del turno | registro de limpieza | 3 | BX095 |
| SX096 | Lo que se cantaba | cuaderno de veterano | 4 | BX096 |
| SX097 | El orden de las válvulas | placa de protocolo | 5 | BX097 |
| SX098 | La muestra de polvo | filtro de ensayo | 6 | BX098 |
| SX099 | El aire y la jornada | acuerdo de mantenimiento | 7 | BX099 |

### SB12. El glosario del hambre — LOC07

Завязка: Una palabra ambigua convierte reservas vecinales de grano en mercancía confiscable.

Авторское решение (спойлер): Un formulario sustituyó reserva por acaparamiento y extendió una orden limitada; algunos almacenes sí ocultaron excedentes.

Цена решения: Liberar reservas domésticas sin legitimar especulación real.

| Квест | Название | Артефакт | Испанский блок | Бой |
|---|---|---|---:|---|
| SX100 | La palabra raspada | formulario de reserva | 1 | BX100 |
| SX101 | El sello de la despensa | sello doméstico | 1 | BX101 |
| SX102 | La medida del saco | tabla de raciones | 2 | BX102 |
| SX103 | El recibo de custodia | recibo de depósito | 2 | BX103 |
| SX104 | La orden posterior | orden de inspección | 3 | BX104 |
| SX105 | La costumbre del invierno | libreta familiar | 4 | BX105 |
| SX106 | El alcance de salvo | copia de excepción | 5 | BX106 |
| SX107 | El doble fondo | inventario contrastado | 6 | BX107 |
| SX108 | Una excepción justa | dictamen de reservas | 7 | BX108 |

## Что осталось подключить

1. Основная работа по плану: знания NPC и детерминированный валидатор.
2. Сохранение состояния расследования, улик и ученика.
3. Полный основной вертикальный срез и интеграция боёв.
4. Планировщик учебных блоков с проверками закрепления.
5. После Gate I — размещение этих веток, журнал, исполнение головоломок,
   варианты мирного доступа и баланс боёв. Не отмечать эти пункты выполненными по наличию JSON.
