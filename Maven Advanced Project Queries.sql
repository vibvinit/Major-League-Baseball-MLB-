
-- PART I: SCHOOL ANALYSIS
-- 1. View the schools and school details tables

SELECT 		*
FROM 		schools;

SELECT 		*
FROM 		school_details;

-- 2. In each decade, how many schools were there that produced players?

SELECT FLOOR(YearID/10)*10 AS decade, count(DISTINCT schoolID) AS schools_count
FROM schools
GROUP BY decade
ORDER BY decade ASC;

-- 3. What are the names of the top 5 schools that produced the most players?

SELECT 	sd.name_full AS school_name, 
		count(distinct s.playerID) AS players_num
FROM schools s LEFT JOIN school_details sd
ON s.schoolID = sd.schoolID
GROUP BY s.schoolID
ORDER BY players_num DESC
LIMIT 5;

-- 4. For each decade, what were the names of the top 3 schools that produced the most players?
WITH ps AS (SELECT FLOOR(s.YearID/10)*10 AS decade, sd.name_full AS school_name, count(DISTINCT playerID) AS player_count
FROM schools s LEFT JOIN school_details sd
ON s.schoolID = sd.schoolID
GROUP BY decade, school_name
ORDER BY decade, player_count DESC),

top AS (SELECT decade, school_name, player_count, 
		ROW_NUMBER() OVER (partition by decade ORDER BY player_count DESC) AS top
FROM ps)

SELECT decade, school_name, player_count
FROM top
WHERE top BETWEEN 1 AND 3
ORDER BY decade DESC, player_count DESC;
		

-- PART II: SALARY ANALYSIS
-- 1. View the salaries table

SELECT *
FROM salaries;

-- 2. Return the top 20% of teams in terms of average annual spending

WITH ts AS (SELECT yearID, teamID, sum(salary /1000000) AS total_spend_mil  -- to get the million we can also use ROUND(SUM(salary/1000000),1)
FROM salaries
GROUP BY yearID, teamID
ORDER BY total_spend_mil DESC),

tas AS (SELECT teamID, ROUND(avg(total_spend_mil),1) AS avg_spend
FROM ts
GROUP BY teamID
ORDER BY avg_spend DESC), 

perc AS (SELECT teamID, avg_spend, 
		NTILE(5) OVER (ORDER BY avg_spend DESC) AS per		-- you can include this in the previous CTE 
FROM tas)

SELECT teamID, avg_spend
FROM perc
WHERE per = 1
ORDER BY avg_spend DESC;


-- 3. For each team, show the cumulative sum of spending over the years
WITH ts AS (SELECT yearID, teamID, sum(salary /1000000) AS total_spend_mil
FROM salaries
GROUP BY yearID, teamID)

SELECT teamID, yearID,
		ROUND(sum(total_spend_mil)  OVER (PARTITION BY teamID ORDER BY yearID),1) AS cum_spend
FROM ts;


-- 4. Return the first year that each team's cumulative spending surpassed 1 billion
WITH ts AS (SELECT yearID, teamID, sum(salary /1000000000) AS total_spend_in_billions
FROM salaries
GROUP BY yearID, teamID),

tcs AS (SELECT teamID, yearID,
		ROUND(sum(total_spend_in_billions) OVER (PARTITION BY teamID ORDER BY yearID),2) AS cum_spend_billion
FROM ts),

tb AS (SELECT teamID, yearID, cum_spend_billion
FROM tcs
WHERE  cum_spend_billion >= 1),

tr AS (SELECT teamID, yearID,cum_spend_billion,
		ROW_NUMBER() OVER (PARTITION BY teamID ORDER BY yearID) As row_num  -- you can use this in the previous CTE
FROM tb)

SELECT teamID, yearID, cum_spend_billion
FROM tr
WHERE row_num =1;

--- 

-- PART III: PLAYER CAREER ANALYSIS
-- 1. View the players table and find the number of players in the table
SELECT COUNT(PlayerID) AS num_of_players
FROM players;

-- 2. For each player, calculate their age at their first game, their last game, and their career length (all in years). Sort from longest career to shortest career.

SELECT		playerID, nameGiven AS player_name, 
			Year(debut) - birthyear AS age_first_game, year(finalGame) - birthyear AS age_last_game,
            year(finalgame) - year(debut) AS careerlength
FROM players
ORDER BY careerlength DESC;

-- 3. What team did each player play on for their starting and ending years?

WITH pi AS (SELECT		playerID, nameGiven AS player_name, year(debut) AS debut_year
			, year(finalGame) AS end_year,
            year(finalgame) - year(debut) AS careerlength
FROM players
ORDER BY careerlength DESC),

 psy AS (SELECT pi.playerID, pi.player_name, debut_year, s.teamID AS starting_team, pi.end_year
FROM pi LEFT JOIN salaries s
ON pi.playerID = s.playerID
WHERE s.yearID = pi.debut_year)

SELECT psy.playerID, psy.player_name, psy.debut_year, psy.starting_team, psy.end_year, s.teamID as ending_team
FROM psy LEFT JOIN salaries s
ON psy.playerID = s.playerID
WHERE s.yearID = psy.end_year
ORDER BY debut_year, psy.starting_team;

-- Alternate soln

SELECT p.playerid, s.yearID AS debut_year, s.teamID as starting_team,
		e.yearID AS end_year, e.teamID AS ending_team
FROM players p INNER JOIN salaries s
				ON p.playerID = s.playerID 
                AND year(p.debut) = s.yearID
			INNER JOIN salaries e
			ON p.playerID = e.playerID 
               AND year(p.finalgame) = e.yearID;


SELECT *
FROM players;
SELECT *
FROM salaries;

-- 4. How many players started and ended on the same team and also played for over a decade?

WITH pi AS (SELECT	playerID, nameGiven AS player_name, year(debut) AS debut_year
			, year(finalGame) AS end_year,
            year(finalgame) - year(debut) AS careerlength
FROM players
ORDER BY careerlength DESC),

 psy AS (SELECT pi.playerID, pi.player_name, pi.debut_year, s.teamID AS starting_team, pi.end_year, pi.careerlength
FROM pi LEFT JOIN salaries s
ON pi.playerID = s.playerID
WHERE s.yearID = pi.debut_year),

pet AS (SELECT psy.playerID, psy.player_name, psy.debut_year, psy.starting_team, psy.end_year, s.teamID as ending_team, psy.careerlength
FROM psy LEFT JOIN salaries s
ON psy.playerID = s.playerID
WHERE s.yearID = psy.end_year)

SELECT player_name, debut_year, starting_team, end_year, ending_team
FROM pet
WHERE starting_team = ending_team AND careerlength > 10
ORDER BY starting_team;


-- Alternate solution

SELECT p.playerid, s.yearID AS debut_year, s.teamID as starting_team,
		e.yearID AS end_year, e.teamID AS ending_team
FROM players p INNER JOIN salaries s
				ON p.playerID = s.playerID 
                AND year(p.debut) = s.yearID
			INNER JOIN salaries e
			ON p.playerID = e.playerID 
               AND year(p.finalgame) = e.yearID
WHERE s.teamID = e.teamID AND e.yearID - s.yearID > 10;

-- PART IV: PLAYER COMPARISON ANALYSIS
-- 1. View the players table
SELECT *
FROM players;

-- 2. Which players have the same birthday?

WITH p AS (SELECT nameGiven AS player_name, CAST(CONCAT(birthYear, '-', birthmonth, '-', birthDay) AS DATE) AS DOB
FROM players)

SELECT DOB, GROUP_CONCAT(player_name SEPARATOR ',') AS players
FROM p
WHERE YEAR(DOB) IS NOT NULL
GROUP BY DOB
HAVING COUNT(player_name) > 1
ORDER BY DOB;

-- 3. Create a summary table that shows for each team, what percent of players bat right, left and both

WITH bat AS (SELECT s.teamID, sum(IF(p.bats = 'R', 1,0)) as right_b, sum(IF(p.bats = 'L',1,0)) AS left_b, 
			sum(IF(p.bats = 'B',1,0)) AS both_b, count(s.playerID) AS total
FROM salaries s LEFT JOIN players p
ON s.playerID = p.playerID
GROUP BY s.teamID)

SELECT 		teamID, right_b/total*100 AS right_b_perc, 
			left_b/total*100 AS left_b_perc,
			both_b/total*100 AS both_b_perc
FROM bat
ORDER BY teamID;


-- ALternate Soln

SELECT 		s.teamID, 
			ROUND(SUM(CASE WHEN p.bats = 'R' THEN 1 ELSE 0 END)/ COUNT(s.playerID)*100,1) AS bats_r_perc,
            ROUND(SUM(CASE WHEN p.bats = 'L' THEN 1 ELSE 0 END)/ COUNT(s.playerID)*100,1) AS bats_l_perc,
            ROUND(SUM(CASE WHEN p.bats = 'B' THEN 1 ELSE 0 END)/ COUNT(s.playerID)*100,1) AS bats_b_perc
FROM 		salaries s LEFT JOIN players p
ON 			s.playerID = p.playerID
GROUP BY 	s.teamID;

-- 4. How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference?

WITH pd AS (SELECT  FLOOR(year(debut)/10)*10 AS yr, avg(weight) AS avg_weight, AVG(height) AS avg_height
FROM players
GROUP BY yr)

SELECT yr, avg_weight, avg_weight - lag(avg_weight) OVER (ORDER BY yr) AS dec_weight_diff, avg_height, avg_height - lag(avg_height) OVER (ORDER BY yr) AS dec_height_diff
FROM pd
WHERE yr IS NOT NULL;
